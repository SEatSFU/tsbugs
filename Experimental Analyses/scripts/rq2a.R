# ============================================================
# RQ2: Correlations Between Bug Categories and Project Attributes
# ============================================================

packages <- c("tidyverse", "Hmisc", "corrplot", "scales", "factoextra")
for (pkg in packages) {
  if (!require(pkg, character.only = TRUE)) install.packages(pkg)
  library(pkg, character.only = TRUE)
}

setwd("PLEASE SET THE PATH TO YOUR WORKING DIRECTORY (WHICH CONTAINS DATA, SCRIPTS, AND OUTPUT DIRECTORIES")

# ---- Step 1: Load data ----
bugs <- read.csv("data/bugs.csv", header = TRUE)
projects <- read.csv("data/projects.csv", header = TRUE)

# ---- Step 2: Normalize bug labels ----
label_map <- c(
  "Type Error" = "Type Error",
  "Missing Cases" = "Missing Case",
  "Missing Features" = "Missing Feature",
  "API Misuse" = "API Misuse",
  "Logic Error" = "Logic Error",
  "Exception Handling" = "Error Handling",
  "Runtime Exception" = "Runtime Exception",
  "Tooling / Configuration Issue" = "Tooling / Config",
  "UI Behavior Bug" = "UI Bug",
  "Test Fault" = "Test Fault",
  "Asynchrony / Event Handling Bug" = "Async / Event"
)
bugs$Bug.Type <- trimws(bugs$Bug.Type)
bugs$Bug.Type <- ifelse(bugs$Bug.Type %in% names(label_map),
                        label_map[bugs$Bug.Type],
                        bugs$Bug.Type)

# ---- Step 3: Aggregate bug counts per project ----
bug_counts <- bugs %>%
  group_by(Project = Project.Name, BugType = Bug.Type) %>%
  summarise(Count = n(), .groups = "drop") %>%
  pivot_wider(names_from = BugType, values_from = Count, values_fill = 0) %>%
  mutate(Total_Bugs = rowSums(across(-Project)))

# ---- Step 4: Prepare project metadata ----
projects <- projects %>%
  mutate(
    `Size (LOC)` = as.numeric(gsub(",", "", `Size..LOC.`)),
    `Num of Files` = as.numeric(`Num.of.Files`),
    `Start Date` = as.Date(`Start.Date`)
  ) %>%
  mutate(Project_Age_Years = as.numeric(difftime(Sys.Date(), `Start Date`, units = "days")) / 365.25)

# ---- Step 5: Merge datasets ----
data_merged <- projects %>%
  left_join(bug_counts, by = "Project")

# ---- Step 6: Prepare bug and project orderings ----
bug_order <- c(
  "Async / Event", "Error Handling", "Missing Case", "Missing Feature",
  "Runtime Exception", "Tooling / Config", "Type Error",
  "Logic Error", "API Misuse", "Test Fault", "UI Bug"
)
project_order <- c(
  "refly", "llamaindexts", "insomnia", "xyflow", "cli",
  "hocuspocus", "n8n", "xstate", "shortest", "user-event",
  "type-challenges", "nest", "vue-i18n", "chakra-ui",
  "fabricjs", "shadcn-table"
)

# ============================================================
# ---- Step 7: Spearman Correlation Heatmap with Significance ----
# ============================================================

#  Define bug and project attributes manually (you can adjust later)
bug_cols <- c(
  "Async / Event", "Error Handling", "Missing Case", "Missing Feature",
  "Runtime Exception", "Tooling / Config", "Type Error",
  "Logic Error", "API Misuse", "Test Fault", "UI Bug"
)

attr_cols <- c(
  "Size..LOC.", "Stars", "Num.of.Files", "Commits", "Commits.in.12.Months..Oct.8.",
  "Issues", "Issues..closed.", "Project_Age_Years", "Num.of.Forks", "Pull.Requests"
)

#  Keep only existing columns to avoid errors
existing_attr_cols <- intersect(attr_cols, colnames(data_merged))
missing_attrs <- setdiff(attr_cols, existing_attr_cols)
if (length(missing_attrs) > 0)
  message("Skipping missing attributes: ", paste(missing_attrs, collapse = ", "))

#  Select relevant columns and remove incomplete rows
numeric_data <- data_merged %>%
  select(all_of(c(bug_cols, existing_attr_cols))) %>%
  mutate(across(everything(), as.numeric)) %>%
  drop_na()

#  Compute Spearman correlation and p-values
cor_matrix <- rcorr(as.matrix(numeric_data), type = "spearman")

#  Extract submatrices
cor_sub  <- cor_matrix$r[bug_cols, existing_attr_cols, drop = FALSE]
pval_sub <- cor_matrix$P[bug_cols, existing_attr_cols, drop = FALSE]

#  Save numeric results
if (!dir.exists("output")) dir.create("output", recursive = TRUE)
write.csv(cor_sub, "output/rq2a_correlations_matrix.csv", row.names = TRUE)
write.csv(pval_sub, "output/rq2a_correlations_pvalues.csv", row.names = TRUE)

# Rename columns just for plotting
pretty_names <- c(
  "Size..LOC." = "LOC",
  "Num.of.Files" = "#Files",
  "Commits.in.12.Months..Oct.8." = "Commits (yr)",
  "Num.of.Forks" = "Forks",
  "Pull.Requests" = "PRs",
  "Issues" = "Issues",
  "Issues..closed." = "Closed Issues",
  "Stars" = "Stars",
  "Commits" = "Commits",
  "Project_Age_Years" = "Age (yrs)"
)
colnames(cor_sub) <- pretty_names[colnames(cor_sub)]


# ============================================================
# ---- RQ2a: Project Attributes × Bug Categories Heatmap ----
# ============================================================

#  Visualize heatmap (no significance marks, no numbers)
pdf("output/rq2a.pdf", width = 8, height = 5)
corrplot(
  cor_sub,
  method = "color",
  type = "full",
  
  # ---- COLOR PALETTE (same as domain heatmap) ----
  col = colorRampPalette(c("#2166AC", "white", "#B2182B"))(200),
  # ---- FONT & LABEL SIZE ----
  tl.col = "black",     # text color for labels
  tl.cex = 1.2,         # label size (try 0.7–1.2)
  tl.srt = 35,          # label rotation
  cl.cex = 1.2,         # colorbar label size
  cl.align.text = "l",  # align colorbar labels left
  
  #  mar = c(0, 0, 2, 0)
  #  title = "Spearman Correlations: Bug Categories vs. Project Attributes"
)

dev.off()

cat("Clean correlation heatmap (no numbers, no symbols) saved to output/rq2a_project_bug_correlations_heatmap_clean.pdf\n")
