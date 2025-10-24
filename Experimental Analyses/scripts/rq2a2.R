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
# ---- Step 8: Domain-level analysis ----
# ============================================================

kw_results <- data.frame(Category = character(), p_value = numeric(), stringsAsFactors = FALSE)
for (col in colnames(bug_counts)[-1]) {
  test <- kruskal.test(data_merged[[col]] ~ as.factor(data_merged$Domain))
  kw_results <- rbind(kw_results, data.frame(Category = col, p_value = test$p.value))
}
write.csv(kw_results, "output/rq2_domain_kw_results.csv", row.names = FALSE)

# ---- Step 9: Domain-level tendencies ----
domain_medians <- data_merged %>%
  group_by(Domain) %>%
  summarise(across(colnames(bug_counts)[-1], median, .names = "{.col}_median")) %>%
  arrange(Domain)

# Standardize via z-score
z_scores <- domain_medians %>%
  pivot_longer(-Domain, names_to = "BugCategory", values_to = "MedianCount") %>%
  mutate(BugCategory = gsub("_median", "", BugCategory)) %>%
  group_by(BugCategory) %>%
  mutate(Z = as.numeric(scale(MedianCount))) %>%
  ungroup() %>%
  filter(BugCategory %in% bug_order)

# ---- Step 10: Domain ordering (cluster-based) ----
domain_order <- tryCatch({
  z_wide <- z_scores %>% select(Domain, BugCategory, Z) %>%
    pivot_wider(names_from = BugCategory, values_from = Z, values_fill = 0) %>%
    column_to_rownames("Domain")
  ord <- fviz_dend(hclust(dist(z_wide)), show_labels = FALSE)
  rownames(z_wide)[ord$data$order]
}, error = function(e) {
  unique(z_scores$Domain)
})


# ============================================================
# ---- Step 11: Domain heatmap (polished MSR-ready version) ----
# ============================================================

library(ggplot2)
library(scales)

# Ensure consistent factor ordering
z_scores$BugCategory <- factor(z_scores$BugCategory, levels = bug_order)
z_scores$Domain <- factor(z_scores$Domain, levels = domain_order)

# Define color scale (balanced and colorblind-friendly)
fill_palette <- scale_fill_gradient2(
  low = "#2166AC", mid = "white", high = "#B2182B", midpoint = 0,
#  limits = c(-2.5, 2.5),   # clamp for more contrast (adjust if needed)
  name = "Relative\nFrequency (z)"
)

# Create the heatmap
pdf("output/rq2a_d.pdf", width = 8.5, height = 4.4)
ggplot(z_scores, aes(x = BugCategory, y = Domain, fill = Z)) +
  geom_tile(color = "gray90", linewidth = 0.3) +
  fill_palette +
  theme_minimal(base_size = 14) +
  theme(
    axis.text.x = element_text(size = 14, angle = 45, hjust = 0.85, margin = margin(t = 0, r = 0, b = -30, l = 0, unit = "pt"), vjust = 1),
#    axis.text.x = element_text(size = 8, angle = 35, hjust = 0.72, margin = margin(t = 0, r = 0, b = -18, l = 0, unit = "pt")),
    axis.text.y = element_text(size = 14),
    axis.title.x = element_text(size = 14, face = "bold", margin = margin(t = 10)),
    axis.title.y = element_text(size = 14, face = "bold", margin = margin(r = 10)),
    panel.grid = element_blank(),
    legend.position = "right",
    legend.title = element_text(size = 14), #, face = "bold"),
    legend.text = element_text(size = 14),
    plot.title = element_text(size = 14, face = "bold", hjust = 0.5, margin = margin(b = 10))
  ) +
  labs(
#    title = "Relative Prevalence of Bug Categories by Domain",
    x = "Bug Category",
    y = "Project Domain"
  )
dev.off()
cat("Polished domain–bug heatmap saved to output/domain_bug_heatmap_ordered_polished.pdf\n")

