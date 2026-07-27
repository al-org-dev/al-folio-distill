# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_distill"
require "digest"
require "json"

# The vendored Distill runtime must be the only origin a Distill page loads the
# template from unless a site explicitly opts into a remote loader.
class RemoteLoaderTest < Minitest::Test
  FakeSite = Struct.new(:config)

  TEMPLATE_SRI = "sha256-#{[["4790831ced02f7c4f2009b2cdf6978ceda8351f0060d3b59dd9b3aab132e271a"].pack("H*")].pack("m0")}"

  def site(distill_config = {}, baseurl: "")
    FakeSite.new({ "baseurl" => baseurl, "al_folio" => { "distill" => distill_config } })
  end

  def render_runtime_scripts(site)
    Liquid::Template.parse("{% al_folio_distill_runtime_scripts %}").render!({}, registers: { site: site })
  end

  def test_runtime_scripts_tag_registered
    assert_equal AlFolioDistill::RuntimeScriptsTag, Liquid::Template.tags["al_folio_distill_runtime_scripts"]
  end

  def test_render_template_delegates_to_runtime_scripts_tag
    render_template = ROOT.join("templates/distill/render.liquid").read

    assert_includes render_template, "{% al_folio_distill_runtime_scripts %}"
    refute_includes render_template, "/assets/js/distillpub/template.v2.js"
    refute_includes render_template, "/assets/js/distillpub/transforms.v2.js"
  end

  def test_default_loads_vendored_runtime_with_pinned_integrity
    output = render_runtime_scripts(site)

    assert_includes output, %(<script src="/assets/js/distillpub/template.v2.js" integrity="#{TEMPLATE_SRI}"></script>)
    assert_includes output, %(src="/assets/js/distillpub/transforms.v2.js" integrity="sha256-)
    refute_includes output, "distill.pub"
  end

  def test_default_loader_descriptor_points_at_vendored_copy
    loader = JSON.parse(render_runtime_scripts(site)[/templateLoader = (\{.*?\});/m, 1])

    assert_equal "/assets/js/distillpub/template.v2.js", loader["url"]
    assert_equal TEMPLATE_SRI, loader["integrity"]
    assert_equal false, loader["remote"]
  end

  def test_vendored_runtime_urls_respect_baseurl
    output = render_runtime_scripts(site({}, baseurl: "/al-folio"))

    assert_includes output, %(src="/al-folio/assets/js/distillpub/template.v2.js")
    assert_includes output, %(src="/al-folio/assets/js/distillpub/transforms.v2.js")
  end

  def test_remote_loader_requires_explicit_opt_in
    refute AlFolioDistill.remote_loader_allowed?(site)
    refute AlFolioDistill.remote_loader_allowed?(site({ "allow_remote_loader" => false }))
    refute AlFolioDistill.remote_loader_allowed?(site({ "allow_remote_loader" => "true" }))
    assert AlFolioDistill.remote_loader_allowed?(site({ "allow_remote_loader" => true }))
  end

  def test_opted_in_remote_loader_emits_integrity_and_crossorigin_when_hash_is_known
    loader = AlFolioDistill.template_loader(
      site(
        {
          "allow_remote_loader" => true,
          "remote_loader_url" => "https://example.test/template.v2.js",
          "remote_loader_integrity" => "sha256-Zm9vYmFy",
        }
      )
    )

    assert_equal "https://example.test/template.v2.js", loader["url"]
    assert_equal "sha256-Zm9vYmFy", loader["integrity"]
    assert_equal true, loader["remote"]
  end

  def test_opted_in_remote_loader_defaults_to_upstream_url_without_integrity
    loader = AlFolioDistill.template_loader(site({ "allow_remote_loader" => true }))

    assert_equal AlFolioDistill::DEFAULT_REMOTE_LOADER_URL, loader["url"]
    refute loader.key?("integrity")
    assert_equal true, loader["remote"]
  end

  def test_opting_in_never_rewrites_the_vendored_script_tags
    output = render_runtime_scripts(site({ "allow_remote_loader" => true }))

    assert_includes output, %(src="/assets/js/distillpub/template.v2.js")
    assert_includes output, %(src="/assets/js/distillpub/transforms.v2.js")
  end

  def test_inline_loader_json_cannot_close_the_script_element
    output = render_runtime_scripts(
      site({ "allow_remote_loader" => true, "remote_loader_url" => "https://example.test/</script><script>alert(1)</script>" })
    )

    refute_includes output, "</script><script>alert(1)"
    assert_includes output, '<\/script>'
  end

  def test_vendored_transforms_no_longer_hard_codes_a_remote_template_loader
    transforms = File.read(ROOT.join("assets/js/distillpub/transforms.v2.js"), encoding: "UTF-8")

    refute_match AlFolioDistill::DISTILL_REMOTE_LOADER_PATTERN, transforms
    assert_includes transforms, "window.alFolioDistill.templateLoader"
  end

  def test_integrity_for_derives_sri_from_the_committed_provenance_digest
    digest = Digest::SHA256.file(ROOT.join("assets/js/distillpub/template.v2.js")).hexdigest

    assert_equal AlFolioDistill.pinned_digest("template.v2.js"), digest
    assert_equal "sha256-#{[[digest].pack("H*")].pack("m0")}", AlFolioDistill.integrity_for("template.v2.js")
    assert_nil AlFolioDistill.integrity_for("not-a-vendored-asset.js")
  end
end
