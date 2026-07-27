# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_distill"
require "json"
require "digest"

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

  def test_distill_scripts_template_uses_cookie_plugin_include
    scripts_template = ROOT.join("templates/distill/scripts.liquid").read
    assert_includes scripts_template, "{% include plugins/al_cookie_scripts.liquid %}"
  end

  def test_distill_scripts_template_uses_tabs_js_not_legacy_minified_path
    scripts_template = ROOT.join("templates/distill/scripts.liquid").read
    assert_includes scripts_template, "/assets/js/tabs.js"
    refute_includes scripts_template, "/assets/js/tabs.min.js"
  end

  def test_distill_scripts_template_uses_back_to_top_cdn_contract
    scripts_template = ROOT.join("templates/distill/scripts.liquid").read
    assert_includes scripts_template, "third_party_libraries['vanilla-back-to-top'].url.js"
    refute_includes scripts_template, "/assets/js/vanilla-back-to-top.min.js"
  end

  def test_runtime_hashes_match_al_folio_main_snapshot_contract
    template_hash = Digest::SHA256.file(ROOT.join("assets/js/distillpub/template.v2.js")).hexdigest
    transforms_hash = Digest::SHA256.file(ROOT.join("assets/js/distillpub/transforms.v2.js")).hexdigest
    overrides_hash = Digest::SHA256.file(ROOT.join("assets/js/distillpub/overrides.js")).hexdigest

    assert_equal "4790831ced02f7c4f2009b2cdf6978ceda8351f0060d3b59dd9b3aab132e271a", template_hash
    assert_equal "5d85590f5652b910ab2411019749c83ef5a5a3fbb9b739adc92b4557b6bf3d39", transforms_hash
    assert_equal "41ce4a3744a9083e8913df1256432d2233ba16ff9b40c4878bdb3f35d73c0e8e", overrides_hash
  end

  def test_runtime_hashes_match_provenance_manifest
    manifest = JSON.parse(ROOT.join("assets/js/distillpub/provenance.json").read)

    %w[template.v2.js transforms.v2.js overrides.js].each do |asset|
      on_disk = Digest::SHA256.file(ROOT.join("assets/js/distillpub", asset)).hexdigest
      assert_equal manifest.dig("assets", asset), on_disk, "#{asset} does not match its pinned provenance digest"
    end
  end

  def test_provenance_manifest_tracks_pinned_upstream_source
    manifest_path = ROOT.join("assets/js/distillpub/provenance.json")
    manifest = JSON.parse(manifest_path.read)

    assert_equal "https://github.com/al-org-dev/distill-template.git", manifest["upstream_repo"]
    assert_equal "al-folio", manifest["upstream_branch"]
    refute_empty manifest["upstream_ref"].to_s
    assert_equal true, manifest["remote_loader_patched"]
    assert_match(/\A[0-9a-f]{64}\z/, manifest.dig("assets", "template.v2.js"))
    assert_match(/\A[0-9a-f]{64}\z/, manifest.dig("assets", "transforms.v2.js"))
    assert_match(/\A[0-9a-f]{64}\z/, manifest.dig("assets", "overrides.js"))
  end
end
