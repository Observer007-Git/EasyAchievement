#!/usr/bin/env node
import fs from "node:fs/promises";
import path from "node:path";
import { SpreadsheetFile, Workbook } from "@oai/artifact-tool";


const [inputPath, outputPath] = process.argv.slice(2);
if (!inputPath || !outputPath) {
  throw new Error("usage: build_reward_workbook.mjs INPUT_JSON OUTPUT_XLSX");
}

const payload = JSON.parse(await fs.readFile(inputPath, "utf8"));
const workbook = Workbook.create();
const dataSheet = workbook.worksheets.add("奖励成就");
const notesSheet = workbook.worksheets.add("说明");
const font = "Arial";
const columnCount = payload.headers.length;
const endColumn = columnName(columnCount);
const headerRow = 4;
const firstDataRow = headerRow + 1;
const lastDataRow = headerRow + payload.rows.length;

dataSheet.showGridLines = false;
dataSheet.getRange(`A1:${endColumn}1`).format.font = {
  name: font,
  size: 14,
  bold: true,
  color: "#1F2937",
};
dataSheet.getRange("A1").values = [["EasyAchievement 奖励成就明细"]];
dataSheet.getRange("A2").values = [[
  `数据构建：${payload.build}　来源：wago.tools DB2　每个奖励 ID 一行`,
]];
dataSheet.getRange(`A2:${endColumn}2`).format.font = {
  name: font,
  size: 10,
  italic: true,
  color: "#6B7280",
};
dataSheet.getRange(`A${headerRow}:${endColumn}${lastDataRow}`).values = [
  payload.headers,
  ...payload.rows,
];
dataSheet.getRange(`A${headerRow}:${endColumn}${lastDataRow}`).format.font = {
  name: font,
  size: 10,
  color: "#1F2937",
};
dataSheet.getRange(`A${headerRow}:${endColumn}${headerRow}`).format = {
  fill: "#334155",
  font: { name: font, size: 10, bold: true, color: "#FFFFFF" },
  horizontalAlignment: "center",
  verticalAlignment: "center",
  wrapText: true,
  borders: { preset: "inside", style: "thin", color: "#FFFFFF" },
};
dataSheet.getRange(`A${firstDataRow}:${endColumn}${lastDataRow}`).format.verticalAlignment = "top";
dataSheet.getRange(`C${firstDataRow}:F${lastDataRow}`).format.wrapText = true;
dataSheet.getRange(`A${firstDataRow}:A${lastDataRow}`).format.numberFormat = "0";
dataSheet.getRange(`G${firstDataRow}:J${lastDataRow}`).format.numberFormat = "0";
dataSheet.getRange(`K${firstDataRow}:${endColumn}${lastDataRow}`).format.numberFormat = "0";
dataSheet.getRange(`A${firstDataRow}:${endColumn}${lastDataRow}`).format.borders = {
  insideHorizontal: { style: "thin", color: "#E5E7EB" },
};
dataSheet.getRange(`A${headerRow}:${endColumn}${lastDataRow}`).format.rowHeight = 30;
dataSheet.getRange(`A${headerRow}:${endColumn}${headerRow}`).format.rowHeight = 36;
setColumnWidths(dataSheet);
dataSheet.freezePanes.freezeRows(headerRow);
dataSheet.freezePanes.freezeColumns(2);
const detailTable = dataSheet.tables.add(
  `A${headerRow}:${endColumn}${lastDataRow}`,
  true,
  "RewardAchievementsTable",
);
detailTable.style = "TableStyleMedium2";
detailTable.showBandedColumns = false;
detailTable.showFilterButton = true;

notesSheet.showGridLines = false;
notesSheet.getRange("A1:D1").format.font = {
  name: font,
  size: 14,
  bold: true,
  color: "#1F2937",
};
notesSheet.getRange("A1").values = [["生成说明"]];
notesSheet.getRange("A3:B9").values = [
  ["项目", "内容"],
  ["游戏构建", payload.build],
  ["生成时间（UTC）", `UTC ${payload.generatedAt}`],
  ["奖励成就数", payload.achievementCount],
  ["奖励明细行数", payload.rewardRowCount],
  ["未解析奖励数", payload.unresolvedCount],
  ["数据源", payload.sourceUrl],
];
notesSheet.getRange("A3:B3").format = sectionHeader(font);
notesSheet.getRange("A4:B9").format.font = { name: font, size: 10, color: "#1F2937" };
notesSheet.getRange("B6:B8").format.numberFormat = "#,##0";
notesSheet.getRange("A11:C11").values = [["中文分类", "分类键", "成就数"]];
notesSheet.getRange(`A12:C${11 + payload.categoryCounts.length}`).values = payload.categoryCounts;
notesSheet.getRange("A11:C11").format = sectionHeader(font);
notesSheet.getRange(`A12:C${11 + payload.categoryCounts.length}`).format.font = {
  name: font,
  size: 10,
  color: "#1F2937",
};
notesSheet.getRange(`C12:C${11 + payload.categoryCounts.length}`).format.numberFormat = "#,##0";
notesSheet.getRange("A21:B21").values = [["字段", "口径"]];
notesSheet.getRange("A22:B26").values = [
  ["奖励ID", "优先使用 Achievement.RewardItemID；为 0 时使用推导奖励物品 ID。"],
  ["奖励ID来源", "成就表、推导或未解析。"],
  ["分类", "根据多张 wago.tools DB2 表的结构化关联和明确奖励类型文本综合生成，可多选。"],
  ["推导奖励物品ID", "由坐骑、宠物、玩具、装饰、外观相关表的法术、来源、名称和集合关系推导。"],
  ["其余字段", "保持 zhCN Achievement.csv 中对应字段的数值。"],
];
notesSheet.getRange("A21:B21").format = sectionHeader(font);
notesSheet.getRange("A22:B26").format.font = { name: font, size: 10, color: "#1F2937" };
notesSheet.getRange("B22:B26").format.wrapText = true;
notesSheet.getRange("A3:C26").format.verticalAlignment = "top";
notesSheet.getRange("A:A").format.columnWidth = 22;
notesSheet.getRange("B:B").format.columnWidth = 72;
notesSheet.getRange("C:C").format.columnWidth = 14;
notesSheet.getRange("A3:C26").format.borders = {
  insideHorizontal: { style: "thin", color: "#E5E7EB" },
};
notesSheet.tabColor = "#64748B";
dataSheet.tabColor = "#1D4ED8";

workbook.recalculate();
const inspection = await workbook.inspect({
  kind: "table",
  range: "奖励成就!A1:J8",
  include: "values,formulas",
  tableMaxRows: 8,
  tableMaxCols: 10,
});
if (!inspection.ndjson.includes("成就ID")) {
  throw new Error("workbook verification failed: detail headers missing");
}
const errors = await workbook.inspect({
  kind: "match",
  searchTerm: "#REF!|#DIV/0!|#VALUE!|#NAME\\?|#N/A|#NUM!|#NULL!|#SPILL!|#CALC!",
  options: { useRegex: true, maxResults: 50 },
  summary: "final formula error scan",
});
if (/\"matchCount\"\s*:\s*[1-9]/.test(errors.ndjson)) {
  throw new Error(`workbook verification failed: ${errors.ndjson}`);
}
const previewDir = process.env.REWARD_WORKBOOK_PREVIEW_DIR;
if (previewDir) {
  await fs.mkdir(previewDir, { recursive: true });
  for (const [sheetName, range, fileName] of [
    ["奖励成就", "A1:J15", "rewards.png"],
    ["说明", "A1:C26", "notes.png"],
  ]) {
    const preview = await workbook.render({
      sheetName,
      range,
      scale: 1.5,
      format: "png",
    });
    await fs.writeFile(
      path.join(previewDir, fileName),
      new Uint8Array(await preview.arrayBuffer()),
    );
  }
}
await fs.mkdir(path.dirname(outputPath), { recursive: true });
const output = await SpreadsheetFile.exportXlsx(workbook);
await output.save(outputPath);


function columnName(count) {
  let name = "";
  while (count > 0) {
    count -= 1;
    name = String.fromCharCode(65 + (count % 26)) + name;
    count = Math.floor(count / 26);
  }
  return name;
}

function sectionHeader(fontName) {
  return {
    fill: "#334155",
    font: { name: fontName, size: 10, bold: true, color: "#FFFFFF" },
    horizontalAlignment: "center",
    verticalAlignment: "center",
  };
}

function setColumnWidths(sheet) {
  const widths = [12, 26, 52, 46, 18, 20, 14, 14, 20, 18];
  widths.forEach((width, index) => {
    sheet.getCell(0, index).format.columnWidth = width;
  });
  sheet.getRange("K:X").format.columnWidth = 15;
}
