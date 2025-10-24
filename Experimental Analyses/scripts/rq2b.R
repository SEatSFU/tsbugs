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




# ---- Step 12: Bug x Bug correlations heatmap ----
# ---- Prepare numeric bug matrix for correlation ----
bug_corr_data <- bug_matrix %>%
  filter(!(Project %in% c("Mean", "TotalBugs"))) %>%   # remove summary rows
  select(-Project) %>%                             # drop non-numeric columns
  mutate_all(as.numeric)                           # ensure all columns numeric

# ---- Compute Spearman correlations ----
bug_corr <- cor(bug_corr_data, method = "spearman", use = "pairwise.complete.obs")

# Exclude the total bugs row and column
excluded_matrix_by_index <- bug_corr[-c(12), -c(12)]

# ---- Optional: check structure ----
str(bug_corr)

# Heatmap
library(corrplot)
pdf("output/rq2b.pdf", width = 7, height = 7)
corrplot(excluded_matrix_by_index, method = "color", type = "lower",
         tl.col = "black", tl.srt = 30,
#         col = colorRampPalette(c("blue", "white", "red"))(200),
         col = colorRampPalette(c("#2166AC", "white", "#B2182B"))(200),
#         title = "Correlations Among Bug Categories"
tl.cex = 1.2,         # label size (try 0.7–1.2)
cl.cex = 1.2         # colorbar label size

)
dev.off()
