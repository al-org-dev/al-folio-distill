# frozen_string_literal: true

require "jekyll"
require "digest"
require "json"
require_relative "al_folio_distill/version"

module AlFolioDistill
  PLUGIN_ROOT = File.expand_path("..", __dir__)
  TEMPLATES_ROOT = File.join(PLUGIN_ROOT, "templates")
  ASSETS_ROOT = File.join(PLUGIN_ROOT, "assets")
  RUNTIME_ROOT = File.join(ASSETS_ROOT, "js", "distillpub")
  RUNTIME_URL_PREFIX = "/assets/js/distillpub"
  PROVENANCE_PATH = File.join(RUNTIME_ROOT, "provenance.json")
  DISTILL_REMOTE_LOADER_PATTERN = %r{https://distill\.pub/template\.v2\.js}
  DEFAULT_REMOTE_LOADER_URL = "https://distill.pub/template.v2.js"
  RUNTIME_SCRIPTS = ["template.v2.js", "transforms.v2.js"].freeze
  SHA256_HEX_PATTERN = /\A[0-9a-f]{64}\z/.freeze

  class PluginStaticFile < Jekyll::StaticFile; end

  module_function

  def enabled?(site)
    site.config.dig("al_folio", "features", "distill", "enabled") != false
  end

  def remote_loader_allowed?(site)
    site.config.dig("al_folio", "distill", "allow_remote_loader") == true
  end

  def remote_loader_url(site)
    configured = site.config.dig("al_folio", "distill", "remote_loader_url")
    configured.is_a?(String) && !configured.empty? ? configured : DEFAULT_REMOTE_LOADER_URL
  end

  def remote_loader_integrity(site)
    configured = site.config.dig("al_folio", "distill", "remote_loader_integrity")
    configured if configured.is_a?(String) && !configured.empty?
  end

  # Committed, known-good digests for the vendored runtime. Refreshed by
  # `scripts/distill/sync_distill.sh`; asserted by the runtime contract test.
  def provenance
    @provenance ||= File.file?(PROVENANCE_PATH) ? JSON.parse(File.read(PROVENANCE_PATH)) : {}
  rescue JSON::ParserError => e
    Jekyll.logger.warn("al_folio_distill:", "could not parse provenance.json (#{e.message}); runtime integrity pinning is disabled")
    @provenance = {}
  end

  def pinned_digest(asset)
    digest = provenance.dig("assets", asset)
    digest if digest.is_a?(String) && digest.match?(SHA256_HEX_PATTERN)
  end

  # Subresource Integrity wants base64, provenance.json pins hex. Same bytes.
  def integrity_for(asset)
    digest = pinned_digest(asset)
    digest && "sha256-#{[[digest].pack("H*")].pack("m0")}"
  end

  def runtime_url(site, asset)
    "#{site.config["baseurl"].to_s.chomp("/")}#{RUNTIME_URL_PREFIX}/#{asset}"
  end

  # Describes where the Distill runtime may be re-injected from after the
  # polyfill transform strips the original tag. Local + pinned unless a site
  # explicitly opts into a remote origin.
  def template_loader(site)
    if remote_loader_allowed?(site)
      { "url" => remote_loader_url(site), "integrity" => remote_loader_integrity(site), "remote" => true }.compact
    else
      { "url" => runtime_url(site, "template.v2.js"), "integrity" => integrity_for("template.v2.js"), "remote" => false }.compact
    end
  end

  class AssetsGenerator < Jekyll::Generator
    safe true
    priority :low

    def generate(site)
      return unless AlFolioDistill.enabled?(site)

      Dir.glob(File.join(ASSETS_ROOT, "**", "*")).sort.each do |source_path|
        next if File.directory?(source_path)

        relative_dir = File.dirname(source_path).sub("#{PLUGIN_ROOT}/", "")
        site.static_files << PluginStaticFile.new(site, PLUGIN_ROOT, relative_dir, File.basename(source_path))
      end
    end
  end

  class RenderTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      return "" unless site && AlFolioDistill.enabled?(site)

      Liquid::Template.parse("{% include distill/render.liquid %}").render!(
        context.environments.first,
        registers: context.registers
      )
    end
  end

  # Emits the vendored Distill runtime with integrity pinned to the committed
  # provenance digests, plus the loader descriptor the patched polyfill
  # transform reads when it re-injects the template tag.
  class RuntimeScriptsTag < Liquid::Tag
    def render(context)
      site = context.registers[:site]
      return "" unless site && AlFolioDistill.enabled?(site)

      lines = [
        "<script>",
        "  window.alFolioDistill = window.alFolioDistill || {};",
        "  window.alFolioDistill.templateLoader = #{json_literal(AlFolioDistill.template_loader(site))};",
        "</script>",
      ]
      AlFolioDistill::RUNTIME_SCRIPTS.each do |asset|
        lines << script_tag(AlFolioDistill.runtime_url(site, asset), AlFolioDistill.integrity_for(asset))
      end
      lines.join("\n")
    end

    private

    def script_tag(url, integrity)
      attributes = %(src="#{escape(url)}")
      attributes += %( integrity="#{escape(integrity)}") if integrity
      "<script #{attributes}></script>"
    end

    # Inline JSON must never be able to close the surrounding <script> element.
    def json_literal(value)
      JSON.generate(value).gsub("</", '<\/')
    end

    def escape(value)
      value.to_s.gsub("&", "&amp;").gsub('"', "&quot;").gsub("<", "&lt;").gsub(">", "&gt;")
    end
  end
end

Liquid::Template.register_tag("al_folio_distill_render", AlFolioDistill::RenderTag)
Liquid::Template.register_tag("al_folio_distill_runtime_scripts", AlFolioDistill::RuntimeScriptsTag)

Jekyll::Hooks.register :site, :after_init do |site|
  next unless site.respond_to?(:includes_load_paths)

  include_path = AlFolioDistill::TEMPLATES_ROOT
  site.includes_load_paths << include_path unless site.includes_load_paths.include?(include_path)
end

Jekyll::Hooks.register :site, :post_read do |site|
  next unless AlFolioDistill.enabled?(site)

  # The served bytes must match the digests we pin in the emitted `integrity`
  # attributes, otherwise every Distill page fails SRI in the browser.
  AlFolioDistill::RUNTIME_SCRIPTS.each do |asset|
    pinned = AlFolioDistill.pinned_digest(asset)
    asset_path = File.join(AlFolioDistill::RUNTIME_ROOT, asset)
    next unless pinned && File.file?(asset_path)
    next if Digest::SHA256.file(asset_path).hexdigest == pinned

    Jekyll.logger.warn(
      "al_folio_distill:",
      "vendored #{asset} does not match the digest pinned in provenance.json; Distill pages will fail subresource integrity"
    )
  end

  if AlFolioDistill.remote_loader_allowed?(site)
    unless AlFolioDistill.remote_loader_integrity(site)
      Jekyll.logger.warn(
        "al_folio_distill:",
        "`al_folio.distill.allow_remote_loader` is true without `al_folio.distill.remote_loader_integrity`; " \
          "the Distill runtime will be loaded from #{AlFolioDistill.remote_loader_url(site)} without subresource integrity"
      )
    end
    next
  end

  transforms_path = File.join(AlFolioDistill::RUNTIME_ROOT, "transforms.v2.js")
  next unless File.file?(transforms_path)

  content = File.read(transforms_path, encoding: "UTF-8")
  if content.match?(AlFolioDistill::DISTILL_REMOTE_LOADER_PATTERN)
    Jekyll.logger.warn("al_folio_distill:", "remote Distill template loader detected while `al_folio.distill.allow_remote_loader` is false")
  end
end
