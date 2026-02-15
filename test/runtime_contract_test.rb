# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_distill"
require "json"

class RuntimeContractTest < Minitest::Test
  def test_render_template_exists
    assert ROOT.join("templates/distill/render.liquid").file?
  end

  def test_assets_are_packaged
    assert ROOT.join("assets/js/distillpub/transforms.v2.js").file?
    assert ROOT.join("assets/js/distillpub/template.v2.js").file?
    assert ROOT.join("assets/js/distillpub/provenance.json").file?
    assert ROOT.join("assets/js/distillpub/overrides.js").file?
    assert ROOT.join("assets/css/al-folio-distill.css").file?
  end

  def test_render_tag_registered
    assert_equal AlFolioDistill::RenderTag, Liquid::Template.tags["al_folio_distill_render"]
  end

  def test_distill_scripts_template_uses_core_cookie_consent_include
    scripts_template = ROOT.join("templates/distill/scripts.liquid").read
    assert_includes scripts_template, "{% include plugins/al_cookie_consent_setup.liquid %}"
    refute_includes scripts_template, "/assets/js/cookie-consent-setup.js"
  end

  def test_transforms_runtime_does_not_reference_remote_template
    content = ROOT.join("assets/js/distillpub/transforms.v2.js").read
    refute_match(%r{https://distill\.pub/template\.v2\.js}, content)
  end

  def test_provenance_manifest_tracks_pinned_upstream_source
    manifest_path = ROOT.join("assets/js/distillpub/provenance.json")
    manifest = JSON.parse(manifest_path.read)

    assert_equal "https://github.com/alshedivat/distillpub-template.git", manifest["upstream_repo"]
    assert_equal "al-folio", manifest["upstream_branch"]
    refute_empty manifest["upstream_ref"].to_s
    assert_equal true, manifest["remote_loader_patched"]
    assert_match(/\A[0-9a-f]{64}\z/, manifest.dig("assets", "template.v2.js"))
    assert_match(/\A[0-9a-f]{64}\z/, manifest.dig("assets", "transforms.v2.js"))
  end
end
