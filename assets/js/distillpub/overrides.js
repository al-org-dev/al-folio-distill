(() => {
  const mark = (el, flag) => {
    if (el && el.dataset) {
      el.dataset[flag] = "true";
    }
  };

  const marked = (el, flag) => Boolean(el && el.dataset && el.dataset[flag] === "true");

  const insertRuleOnce = (styleEl, rule) => {
    if (!styleEl || !styleEl.sheet) {
      return;
    }
    for (const existing of styleEl.sheet.cssRules) {
      if (existing.cssText === rule) {
        return;
      }
    }
    styleEl.sheet.insertRule(rule, styleEl.sheet.cssRules.length);
  };

  const styleHoverPanel = (host) => {
    const hoverBox = host?.querySelector("d-hover-box");
    const styleTag = hoverBox?.shadowRoot?.querySelector("style");
    insertRuleOnce(styleTag, ".panel {background-color: var(--global-bg-color) !important;}");
    insertRuleOnce(styleTag, ".panel {border-color: var(--global-divider-color) !important;}");
  };

  const styleFootnote = (footnote) => {
    if (marked(footnote, "afDistillStyled")) {
      return true;
    }
    const root = footnote.shadowRoot;
    if (!root) {
      return false;
    }

    const marker = root.querySelector("sup > span");
    if (marker) {
      marker.style.color = "var(--global-theme-color)";
    }
    styleHoverPanel(root);
    mark(footnote, "afDistillStyled");
    return true;
  };

  const styleCite = (cite) => {
    if (marked(cite, "afDistillStyled")) {
      return true;
    }
    const root = cite.shadowRoot;
    if (!root) {
      return false;
    }

    const citation = root.querySelector("div > span");
    if (citation) {
      citation.style.color = "var(--global-theme-color)";
    }

    const citeStyleTag = root.querySelector("style");
    insertRuleOnce(citeStyleTag, "ul li a {color: var(--global-text-color) !important; text-decoration: none;}");
    insertRuleOnce(citeStyleTag, "ul li a:hover {color: var(--global-theme-color) !important;}");
    styleHoverPanel(root);
    mark(cite, "afDistillStyled");
    return true;
  };

  const applyOverrides = () => {
    let pending = false;

    document.querySelectorAll("d-footnote").forEach((footnote) => {
      pending = !styleFootnote(footnote) || pending;
    });
    document.querySelectorAll("d-cite").forEach((cite) => {
      pending = !styleCite(cite) || pending;
    });

    return pending;
  };

  window.addEventListener("load", () => {
    let attempts = 0;
    const maxAttempts = 12;

    const run = () => {
      const pending = applyOverrides();
      attempts += 1;
      if (pending && attempts < maxAttempts) {
        window.setTimeout(run, 250);
      }
    };

    run();

    const observer = new MutationObserver(() => {
      applyOverrides();
    });
    observer.observe(document.body, { childList: true, subtree: true });
  });
})();
