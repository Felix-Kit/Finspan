#!/usr/bin/env node

import fs from "node:fs";
import http from "node:http";
import path from "node:path";
import { createRequire } from "node:module";
import { fileURLToPath } from "node:url";

const __filename = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(__filename), "../..");
const liveRoot = path.join(repoRoot, "references/webpage_live");
const outputDir = path.join(repoRoot, "tools/generated/card_rendering");
const screenshotsDir = path.join(outputDir, "screenshots");
const jsonPath = path.join(outputDir, "live_measurements.json");
const markdownPath = path.join(repoRoot, "docs/CARD_RENDERING_LIVE_MEASUREMENTS.md");

const targetCards = [
  { cardId: "base.main.014", sourceId: 14, name: "Banggai Cardinalfish" },
  { cardId: "base.main.057", sourceId: 57, name: "Great White Shark" },
  { cardId: "base.main.016", sourceId: 16, name: "Bearded Seadevil" },
  { cardId: "sr.starter.212", sourceId: 212, name: "Atlantic Barracudina" },
  { cardId: "sr.main.161", sourceId: 161, name: "Great Barracuda" },
  { cardId: "base.main.001", sourceId: 1, name: "Abyssal Anglerfish" },
  { cardId: "base.main.056", sourceId: 56, name: "Great Northern Tilefish" }
];

const mimeTypes = new Map([
  [".html", "text/html"],
  [".js", "application/javascript"],
  [".css", "text/css"],
  [".svg", "image/svg+xml"],
  [".png", "image/png"],
  [".webp", "image/webp"],
  [".json", "application/json"],
  [".otf", "font/otf"],
  [".woff", "font/woff"],
  [".ico", "image/x-icon"]
]);

function rounded(value, places = 3) {
  if (value == null || Number.isNaN(value)) {
    return null;
  }
  const factor = 10 ** places;
  return Math.round(value * factor) / factor;
}

function createStaticServer(preferredPort = 4173) {
  const server = http.createServer((request, response) => {
    let urlPath = decodeURIComponent(new URL(request.url, "http://127.0.0.1").pathname);
    if (urlPath === "/" || urlPath === "/finsearch" || urlPath === "/finsearch/") {
      urlPath = "/index.html";
    }
    if (urlPath.startsWith("/finsearch/")) {
      urlPath = urlPath.slice("/finsearch".length);
    }

    const filePath = path.join(liveRoot, urlPath);
    if (!filePath.startsWith(liveRoot)) {
      response.writeHead(403);
      response.end("forbidden");
      return;
    }

    fs.readFile(filePath, (error, contents) => {
      if (error) {
        response.writeHead(404);
        response.end(`not found: ${urlPath}`);
        return;
      }
      response.writeHead(200, {
        "content-type": mimeTypes.get(path.extname(filePath)) ?? "application/octet-stream"
      });
      response.end(contents);
    });
  });

  return new Promise((resolve, reject) => {
    const listen = port => {
      server.once("error", error => {
        if (port === preferredPort && error.code === "EADDRINUSE") {
          listen(0);
          return;
        }
        reject(error);
      });
      server.listen(port, "127.0.0.1", () => resolve(server));
    };
    listen(preferredPort);
  });
}

async function importPlaywright() {
  const require = createRequire(import.meta.url);
  try {
    return require("playwright");
  } catch (error) {
    const hint = [
      "Unable to import Playwright.",
      "Install it outside the repo, for example:",
      "  mkdir -p /tmp/finspan-playwright",
      "  cd /tmp/finspan-playwright",
      "  npm init -y",
      "  npm install playwright",
      "  npx playwright install chromium",
      "Then run with:",
      "  NODE_PATH=/tmp/finspan-playwright/node_modules node tools/scripts/measure_live_card_dom.mjs"
    ].join("\n");
    throw new Error(`${hint}\n\nOriginal error: ${error.message}`);
  }
}

function relativeAssetPath(urlString) {
  if (!urlString || urlString === "none") {
    return null;
  }
  const cleaned = urlString
    .trim()
    .replace(/^url\(["']?/, "")
    .replace(/["']?\)$/, "");
  let pathname = cleaned;
  try {
    pathname = new URL(cleaned).pathname;
  } catch {
    // `cleaned` may already be a path-like value from a CSS url().
  }
  const match = pathname.match(/\/finsearch\/(.+)$/);
  if (!match?.[1]) {
    return null;
  }
  return `references/webpage_live/${match[1]}`;
}

function pngDimensions(filePath) {
  if (!filePath.endsWith(".png") || !fs.existsSync(filePath)) {
    return null;
  }
  const buffer = fs.readFileSync(filePath);
  if (
    buffer.length < 24
    || buffer.readUInt32BE(0) !== 0x89504e47
    || buffer.readUInt32BE(4) !== 0x0d0a1a0a
    || buffer.toString("ascii", 12, 16) !== "IHDR"
  ) {
    return null;
  }
  return {
    width: buffer.readUInt32BE(16),
    height: buffer.readUInt32BE(20)
  };
}

function coverRenderingMetrics(frame, intrinsic) {
  if (!frame || !intrinsic || intrinsic.width <= 0 || intrinsic.height <= 0) {
    return null;
  }
  const coverScale = Math.max(frame.width / intrinsic.width, frame.height / intrinsic.height);
  const renderedWidth = intrinsic.width * coverScale;
  const renderedHeight = intrinsic.height * coverScale;
  return {
    intrinsicWidth: intrinsic.width,
    intrinsicHeight: intrinsic.height,
    intrinsicAspectRatio: rounded(intrinsic.width / intrinsic.height),
    frameAspectRatio: rounded(frame.width / frame.height),
    coverScale: rounded(coverScale, 6),
    renderedWidth: rounded(renderedWidth),
    renderedHeight: rounded(renderedHeight),
    cropRight: rounded(Math.max(0, renderedWidth - frame.width)),
    cropBottom: rounded(Math.max(0, renderedHeight - frame.height))
  };
}

function generateMarkdown(report) {
  const lines = [];
  lines.push("# Card Rendering Live Measurements");
  lines.push("");
  lines.push(`Generated: ${report.generatedAt}`);
  lines.push("");
  lines.push("Source of truth: local render of `references/webpage_live/index.html` through Chromium/Playwright. The local server maps `/finsearch/*` to the mirrored live assets so computed CSS matches the published finsearch paths.");
  lines.push("");
  lines.push("## Summary");
  lines.push("");
  lines.push("| Card | Card frame px | Ability panel px | Panel cqw | Right gap cqw | Blocks | Brush mode |");
  lines.push("| --- | ---: | ---: | ---: | ---: | ---: | --- |");
  for (const card of report.cards) {
    const panel = card.abilityContainer;
    const firstBlock = card.abilityBlocks[0];
    lines.push([
      `| ${card.cardId} ${card.name}`,
      `${card.cardFrame.width} x ${card.cardFrame.height}`,
      panel ? `${panel.width} x ${panel.height}` : "none",
      panel ? `${panel.cqw.left} / ${panel.cqw.width}` : "none",
      panel ? panel.cqw.rightGap : "none",
      card.abilityBlocks.length,
      firstBlock ? `${firstBlock.background.assetName ?? "none"}; size ${firstBlock.background.size}; pos ${firstBlock.background.position}; repeat ${firstBlock.background.repeat}; origin ${firstBlock.background.origin}; clip ${firstBlock.background.clip}` : "none"
    ].join(" | ") + " |");
  }
  lines.push("");
  lines.push("## Brush Background Findings");
  lines.push("");
  lines.push("- Live ability blocks use CSS `background-image` on `.ability`, not a foreground `img`.");
  lines.push("- Computed `background-size` is `cover`.");
  lines.push("- Computed `background-position` is `0% 0%`.");
  lines.push("- Computed `background-repeat` is `repeat` because CSS does not override the default, but `background-size: cover` makes the single brush image cover each block frame.");
  lines.push("- Computed `background-origin` is `padding-box`; computed `background-clip` is `border-box`.");
  lines.push("- No representative block reports a transform or rotation on the brush element.");
  lines.push("- The correct Swift mapping is therefore an unrotated, top-leading cover/crop of the same brush raster, with the block frame measured from live layout.");
  lines.push("");
  lines.push("## Card Details");
  lines.push("");
  for (const card of report.cards) {
    lines.push(`### ${card.cardId} ${card.name}`);
    lines.push("");
    lines.push(`- Card frame: ${JSON.stringify(card.cardFrame)}`);
    lines.push(`- Ability container: ${card.abilityContainer ? JSON.stringify(card.abilityContainer) : "none"}`);
    lines.push(`- Swift pre-fix estimated panel frame: ${JSON.stringify(card.swiftBefore.abilityPanelFrame)}`);
    lines.push("");
    lines.push("| Block | Classes | Frame px | Frame cqw | Content inset cqw | Background | Rendered brush | Padding px |");
    lines.push("| ---: | --- | ---: | ---: | ---: | --- | --- | --- |");
    card.abilityBlocks.forEach((block, index) => {
      lines.push([
        `| ${index + 1}`,
        block.className,
        `${block.frame.width} x ${block.frame.height} @ ${block.frame.left}, ${block.frame.top}`,
        `x ${block.cqw.left}; y ${block.cqw.top}; w ${block.cqw.width}; h ${block.cqw.height}`,
        block.contentInsetsCqw ? `t ${block.contentInsetsCqw.top}; b ${block.contentInsetsCqw.bottom}; l ${block.contentInsetsCqw.left}; r ${block.contentInsetsCqw.right}` : "none",
        `${block.background.assetName ?? "none"}; ${block.background.size}; ${block.background.position}; ${block.background.repeat}; origin ${block.background.origin}; clip ${block.background.clip}; transform ${block.background.transform}`,
        block.background.rendered ? `${block.background.rendered.renderedWidth} x ${block.background.rendered.renderedHeight}; crop r ${block.background.rendered.cropRight}; b ${block.background.rendered.cropBottom}` : "none",
        `t ${block.padding.top}; r ${block.padding.right}; b ${block.padding.bottom}; l ${block.padding.left}`
      ].join(" | ") + " |");
    });
    if (card.alsoIfGap) {
      lines.push(`- also-if gap: ${JSON.stringify(card.alsoIfGap)}`);
    }
    if (card.arrowDown) {
      lines.push(`- ArrowDown: ${JSON.stringify(card.arrowDown)}`);
    }
    lines.push(`- Ability icons: ${card.abilityIcons.map(icon => `${icon.className}@${icon.cqw.left},${icon.cqw.top} ${icon.cqw.width}x${icon.cqw.height}`).join("; ") || "none"}`);
    lines.push("");
  }
  lines.push("## Fix Guidance");
  lines.push("");
  lines.push("- Use measured live cqw frames for `CardAbilityPanelMetrics` instead of undocumented offsets.");
  lines.push("- Render brush backgrounds with live `cover` semantics and top-leading alignment; do not cap-inset stretch the raster.");
  lines.push("- Keep ArrowDown metrics tied to measured `.ArrowDown { height: 15cqw; margin: -5cqw 0; }` and representative overlap results.");
  lines.push("");
  lines.push("## Applied Swift Mapping");
  lines.push("");
  lines.push("- `CardAbilityPanelMetrics.live` now uses the measured container frame: left `71.883cqw`, top `0.266cqw`, width `27.851cqw`, height `65.218cqw`, right gap `0.266cqw`, block gap `1.986cqw`.");
  lines.push("- `CardAbilityBrushMetrics.live` now records `assetContentMode = coverTopLeading`, `backgroundPosition = 0% 0%`, `backgroundRepeat = repeat`, `capInsetCqw = 0`, and `cornerRadiusCqw = 0`.");
  lines.push("- `CardAbilityBrushBackgroundView` maps CSS background cover with top-leading alignment by calculating the cover-scaled image size from the measured block frame and clipping to that frame.");
  lines.push("- Swift applies the brush as a block `.background`, not a `ZStack` content child, because live CSS background images do not participate in ability block layout.");
  lines.push("- `CardAbilityBlockMetrics` uses measured minimum heights: standard `27.842cqw`, squished `17.993cqw`, also-if `35.286cqw`.");
  lines.push("- DEBUG card face status can show the live measured frame, current Swift frame, and delta when `tools/generated/card_rendering/live_measurements.json` is present.");
  lines.push("");
  return lines.join("\n");
}

async function measureCard(page, baseUrl, target) {
  await page.locator("input").fill(target.name);
  await page.waitForTimeout(500);
  await page.waitForSelector(".card", { timeout: 10000 });

  const cards = await page.locator(".card").count();
  if (cards < 1) {
    throw new Error(`No rendered card found for ${target.name}`);
  }

  const screenshotPath = path.join(screenshotsDir, `${target.cardId.replaceAll(".", "_")}.png`);
  await page.locator(".card").first().screenshot({ path: screenshotPath });

  return await page.locator(".card").first().evaluate((card, target) => {
    const rect = element => {
      if (!element) return null;
      const box = element.getBoundingClientRect();
      return {
        x: box.x,
        y: box.y,
        width: box.width,
        height: box.height,
        top: box.top,
        right: box.right,
        bottom: box.bottom,
        left: box.left
      };
    };
    const px = value => Number.parseFloat(value || "0") || 0;
    const styleMap = (element, names) => {
      if (!element) return {};
      const style = getComputedStyle(element);
      return Object.fromEntries(names.map(name => [name, style[name]]));
    };
    const toCqw = (cardRect, value) => Math.round((value / cardRect.width) * 100000) / 1000;
    const cqwRect = (cardRect, elementRect) => {
      if (!elementRect) return null;
      return {
        left: toCqw(cardRect, elementRect.left - cardRect.left),
        top: toCqw(cardRect, elementRect.top - cardRect.top),
        width: toCqw(cardRect, elementRect.width),
        height: toCqw(cardRect, elementRect.height),
        rightGap: toCqw(cardRect, cardRect.right - elementRect.right),
        bottomGap: toCqw(cardRect, cardRect.bottom - elementRect.bottom)
      };
    };
    const unionRect = rects => {
      const nonEmpty = rects.filter(item => item && item.width > 0 && item.height > 0);
      if (nonEmpty.length === 0) return null;
      const left = Math.min(...nonEmpty.map(item => item.left));
      const top = Math.min(...nonEmpty.map(item => item.top));
      const right = Math.max(...nonEmpty.map(item => item.right));
      const bottom = Math.max(...nonEmpty.map(item => item.bottom));
      return {
        x: left,
        y: top,
        width: right - left,
        height: bottom - top,
        top,
        right,
        bottom,
        left
      };
    };
    const contentFrameFor = block => {
      const children = [...block.querySelectorAll(".ability-text, .icon-group, img, .points")];
      return unionRect(children.map(rect));
    };
    const contentInsets = (outer, inner) => {
      if (!outer || !inner) return null;
      return {
        top: inner.top - outer.top,
        right: outer.right - inner.right,
        bottom: outer.bottom - inner.bottom,
        left: inner.left - outer.left
      };
    };
    const contentInsetsCqw = (cardRect, outer, inner) => {
      const insets = contentInsets(outer, inner);
      if (!insets) return null;
      return {
        top: toCqw(cardRect, insets.top),
        right: toCqw(cardRect, insets.right),
        bottom: toCqw(cardRect, insets.bottom),
        left: toCqw(cardRect, insets.left)
      };
    };
    const computedNumber = (element, name) => px(getComputedStyle(element)[name]);
    const computedCqwNumber = (cardRect, element, name) => toCqw(cardRect, computedNumber(element, name));
    const className = element => typeof element?.className === "string" ? element.className : "";
    const assetNameFromBackground = backgroundImage => {
      const match = backgroundImage?.match(/\/([^/.]+)\.[a-f0-9]+\.(png|webp|svg)/);
      return match ? match[1] : null;
    };
    const title = card.querySelector(".name .title")?.textContent?.replace(/\s+/g, " ").trim() ?? "";
    const cardRect = rect(card);
    const abilityContainer = card.querySelector(".ability-container");
    const containerRect = rect(abilityContainer);
    const abilityBlocks = [...card.querySelectorAll(".ability")].map(block => {
      const blockRect = rect(block);
      const styles = styleMap(block, [
        "backgroundImage",
        "backgroundSize",
        "backgroundPosition",
        "backgroundRepeat",
        "backgroundOrigin",
        "backgroundClip",
        "backgroundAttachment",
        "backgroundColor",
        "borderRadius",
        "clipPath",
        "overflow",
        "objectFit",
        "transform",
        "zIndex",
        "display",
        "position",
        "justifyContent",
        "alignItems",
        "gap",
        "width",
        "height",
        "minHeight",
        "paddingTop",
        "paddingRight",
        "paddingBottom",
        "paddingLeft",
        "fontSize",
        "lineHeight",
        "boxSizing"
      ]);
      const contentFrame = contentFrameFor(block);
      return {
        className: className(block),
        frame: blockRect,
        cqw: cqwRect(cardRect, blockRect),
        contentFrame,
        contentCqw: cqwRect(cardRect, contentFrame),
        contentInsets: contentInsets(blockRect, contentFrame),
        contentInsetsCqw: contentInsetsCqw(cardRect, blockRect, contentFrame),
        background: {
          image: styles.backgroundImage,
          assetName: assetNameFromBackground(styles.backgroundImage),
          size: styles.backgroundSize,
          position: styles.backgroundPosition,
          repeat: styles.backgroundRepeat,
          origin: styles.backgroundOrigin,
          clip: styles.backgroundClip,
          attachment: styles.backgroundAttachment,
          color: styles.backgroundColor,
          transform: styles.transform,
          borderRadius: styles.borderRadius,
          overflow: styles.overflow,
          clipPath: styles.clipPath,
          zIndex: styles.zIndex
        },
        layout: {
          display: styles.display,
          position: styles.position,
          justifyContent: styles.justifyContent,
          alignItems: styles.alignItems,
          gap: styles.gap,
          width: styles.width,
          height: styles.height,
          minHeight: styles.minHeight,
          fontSize: styles.fontSize,
          lineHeight: styles.lineHeight,
          boxSizing: styles.boxSizing
        },
        padding: {
          top: px(styles.paddingTop),
          right: px(styles.paddingRight),
          bottom: px(styles.paddingBottom),
          left: px(styles.paddingLeft),
          cqw: {
            top: computedCqwNumber(cardRect, block, "paddingTop"),
            right: computedCqwNumber(cardRect, block, "paddingRight"),
            bottom: computedCqwNumber(cardRect, block, "paddingBottom"),
            left: computedCqwNumber(cardRect, block, "paddingLeft")
          }
        }
      };
    });
    const titleElements = [...card.querySelectorAll(".ability .ability-text.bold")].map(element => ({
      text: element.textContent?.replace(/\s+/g, " ").trim() ?? "",
      className: className(element),
      frame: rect(element),
      cqw: cqwRect(cardRect, rect(element)),
      style: styleMap(element, ["fontSize", "fontWeight", "lineHeight", "paddingLeft", "textAlign", "position", "zIndex"])
    }));
    const abilityIcons = [...card.querySelectorAll(".ability img")].map((icon, index) => {
      const iconRect = rect(icon);
      const styles = styleMap(icon, [
        "height",
        "width",
        "maxHeight",
        "maxWidth",
        "marginTop",
        "marginRight",
        "marginBottom",
        "marginLeft",
        "position",
        "bottom",
        "filter",
        "zIndex",
        "objectFit",
        "transform"
      ]);
      return {
        index,
        className: className(icon),
        alt: icon.getAttribute("alt"),
        src: icon.currentSrc || icon.getAttribute("src"),
        frame: iconRect,
        cqw: cqwRect(cardRect, iconRect),
        style: styles,
        marginCqw: {
          top: computedCqwNumber(cardRect, icon, "marginTop"),
          right: computedCqwNumber(cardRect, icon, "marginRight"),
          bottom: computedCqwNumber(cardRect, icon, "marginBottom"),
          left: computedCqwNumber(cardRect, icon, "marginLeft")
        }
      };
    });
    const arrowIndex = abilityIcons.findIndex(icon => icon.className.includes("ArrowDown"));
    const arrowDown = arrowIndex >= 0 ? {
      icon: abilityIcons[arrowIndex],
      previousIcon: abilityIcons[arrowIndex - 1] ?? null,
      nextIcon: abilityIcons[arrowIndex + 1] ?? null,
      topOverlapPx: abilityIcons[arrowIndex - 1] ? abilityIcons[arrowIndex - 1].frame.bottom - abilityIcons[arrowIndex].frame.top : null,
      bottomOverlapPx: abilityIcons[arrowIndex + 1] ? abilityIcons[arrowIndex].frame.bottom - abilityIcons[arrowIndex + 1].frame.top : null,
      topOverlapCqw: abilityIcons[arrowIndex - 1] ? toCqw(cardRect, abilityIcons[arrowIndex - 1].frame.bottom - abilityIcons[arrowIndex].frame.top) : null,
      bottomOverlapCqw: abilityIcons[arrowIndex + 1] ? toCqw(cardRect, abilityIcons[arrowIndex].frame.bottom - abilityIcons[arrowIndex + 1].frame.top) : null
    } : null;
    const alsoIfBlocks = abilityBlocks.filter(block => block.className.includes("also-if"));
    const alsoIfGap = abilityBlocks.length > 1 ? {
      px: abilityBlocks[1].frame.top - abilityBlocks[0].frame.bottom,
      cqw: toCqw(cardRect, abilityBlocks[1].frame.top - abilityBlocks[0].frame.bottom)
    } : null;
    const silhouette = card.querySelector(".silhouette");
    const description = card.querySelector(".description");
    return {
      cardId: target.cardId,
      sourceId: target.sourceId,
      name: target.name,
      renderedTitle: title,
      cardText: card.innerText,
      cardFrame: cardRect,
      cardAspectRatio: cardRect.width / cardRect.height,
      abilityContainer: containerRect ? {
        frame: containerRect,
        ...containerRect,
        cqw: cqwRect(cardRect, containerRect),
        style: styleMap(abilityContainer, [
          "display",
          "flexDirection",
          "gap",
          "height",
          "justifyContent",
          "minWidth",
          "paddingTop",
          "position",
          "right",
          "transform",
          "zIndex"
        ])
      } : null,
      abilityBlocks,
      triggerTitles: titleElements,
      abilityIcons,
      arrowDown,
      alsoIfBlockCount: alsoIfBlocks.length,
      alsoIfGap,
      silhouette: silhouette ? { frame: rect(silhouette), cqw: cqwRect(cardRect, rect(silhouette)), style: styleMap(silhouette, ["maxHeight", "maxWidth", "top", "left", "opacity", "filter", "transform", "zIndex"]) } : null,
      description: description ? { text: description.textContent?.trim() ?? "", frame: rect(description), cqw: cqwRect(cardRect, rect(description)), style: styleMap(description, ["fontSize", "lineHeight", "top", "left", "width", "fontFamily", "fontStyle"]) } : null
    };
  }, target);
}

function attachDerivedData(report) {
  for (const card of report.cards) {
    const cardWidth = card.cardFrame.width;
    const cardHeight = card.cardFrame.height;
    const unit = cardWidth / 100;
    const panelWidth = 28 * unit;
    const panelHeight = (100 / (61 / 40) - 1) * unit;
    card.swiftBefore = {
      notes: "Swift state before this pass used CardAbilityPanelMetrics.live width=28cqw, top=1cqw, trailing=0cqw, height=(100/aspect)-1cqw and CardAbilityBrushMetrics.assetContentMode=stretch.",
      abilityPanelFrame: {
        left: rounded(card.cardFrame.right - panelWidth),
        top: rounded(card.cardFrame.top + unit),
        width: rounded(panelWidth),
        height: rounded(panelHeight),
        rightGap: 0,
        cqw: {
          left: 72,
          top: 1,
          width: 28,
          height: rounded(100 / (61 / 40) - 1),
          rightGap: 0
        }
      },
      brushContentMode: "stretch",
      brushUsesCapInsets: true,
      brushAlignment: "center"
    };
    card.assets = {
      brushAssets: [...new Set(card.abilityBlocks.map(block => block.background.assetName).filter(Boolean))].map(assetName => ({
        assetName,
        webpagePath: relativeAssetPath(card.abilityBlocks.find(block => block.background.assetName === assetName)?.background.image)
      }))
    };
    for (const block of card.abilityBlocks) {
      const relativePath = relativeAssetPath(block.background.image);
      const absolutePath = relativePath ? path.join(repoRoot, relativePath) : null;
      const intrinsic = absolutePath ? pngDimensions(absolutePath) : null;
      block.background.webpagePath = relativePath;
      block.background.rendered = coverRenderingMetrics(block.frame, intrinsic);
      if (block.background.rendered && card.cardFrame.width > 0) {
        block.background.rendered.cqw = {
          renderedWidth: rounded((block.background.rendered.renderedWidth / card.cardFrame.width) * 100),
          renderedHeight: rounded((block.background.rendered.renderedHeight / card.cardFrame.width) * 100),
          cropRight: rounded((block.background.rendered.cropRight / card.cardFrame.width) * 100),
          cropBottom: rounded((block.background.rendered.cropBottom / card.cardFrame.width) * 100)
        };
      }
    }
    card.roundedCardFrame = {
      width: rounded(cardWidth),
      height: rounded(cardHeight)
    };
  }
}

async function main() {
  fs.mkdirSync(outputDir, { recursive: true });
  fs.mkdirSync(screenshotsDir, { recursive: true });

  const { chromium } = await importPlaywright();
  const server = await createStaticServer();
  const port = server.address().port;
  const baseUrl = `http://127.0.0.1:${port}/finsearch/`;
  const browser = await chromium.launch({ headless: true });
  const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 1 });

  const report = {
    generatedAt: new Date().toISOString(),
    measurementSource: {
      kind: "local-playwright-dom",
      url: baseUrl,
      liveRoot: path.relative(repoRoot, liveRoot),
      viewport: { width: 1400, height: 1000, deviceScaleFactor: 1 },
      playwright: "chromium"
    },
    cards: []
  };

  try {
    await page.goto(baseUrl, { waitUntil: "networkidle" });
    await page.waitForSelector(".card", { timeout: 15000 });
    for (const target of targetCards) {
      report.cards.push(await measureCard(page, baseUrl, target));
    }
  } finally {
    await browser.close();
    await new Promise(resolve => server.close(resolve));
  }

  attachDerivedData(report);
  fs.writeFileSync(jsonPath, `${JSON.stringify(report, null, 2)}\n`);
  fs.writeFileSync(markdownPath, `${generateMarkdown(report)}\n`);
  console.log(`Wrote ${path.relative(repoRoot, jsonPath)}`);
  console.log(`Wrote ${path.relative(repoRoot, markdownPath)}`);
}

main().catch(error => {
  console.error(error);
  process.exit(1);
});
