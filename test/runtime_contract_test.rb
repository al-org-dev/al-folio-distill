# frozen_string_literal: true

require_relative "test_helper"
require "al_folio_distill"

class RuntimeContractTest < Minitest::Test
  def test_render_template_exists
    assert ROOT.join("templates/distill/render.liquid").file?
  end

  def test_assets_are_packaged
    assert ROOT.join("assets/js/distillpub/transforms.v2.js").file?
    assert ROOT.join("assets/js/distillpub/template.v2.js").file?
    assert ROOT.join("assets/js/distillpub/overrides.js").file?
    assert ROOT.join("assets/css/al-folio-distill.css").file?
  end

  def test_render_tag_registered
    assert_equal AlFolioDistill::RenderTag, Liquid::Template.tags["al_folio_distill_render"]
  end

  def test_transforms_runtime_does_not_reference_remote_template
    content = ROOT.join("assets/js/distillpub/transforms.v2.js").read
    refute_match(%r{https://distill\.pub/template\.v2\.js}, content)
  end
end
