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
# ---- Step 7: Spearman Correlation Heatmap (axes flipped) ----
# ============================================================

numeric_data <- data_merged %>%
  select(where(is.numeric)) %>%
  drop_na()

# Compute Spearman correlation
cor_matrix <- rcorr(as.matrix(numeric_data), type = "spearman")

# Save correlation results
if (!dir.exists("output")) dir.create("output", recursive = TRUE)
write.csv(as.data.frame(cor_matrix$r), "output/rq2_correlations_matrix.csv", row.names = TRUE)
write.csv(as.data.frame(cor_matrix$P), "output/rq2_correlations_pvalues.csv", row.names = TRUE)

# Prepare subset for visualization (exclude Total_Bugs)
bug_cols <- intersect(bug_order, colnames(numeric_data))
attr_cols <- setdiff(colnames(numeric_data), c(bug_cols, "Total_Bugs"))

# Extract sub-matrix (bug categories as rows, attributes as columns)
cor_sub <- cor_matrix$r[bug_cols, attr_cols, drop = FALSE]

# Save and visualize heatmap with flipped axes
pdf("output/rq2_correlations_heatmap.pdf", width = 9, height = 6)
corrplot(
  cor_sub,
  method = "color",
  type = "full",
  tl.col = "black",
  tl.srt = 45,
  col = colorRampPalette(c("blue", "white", "red"))(200),
  mar = c(0, 0, 2, 0),
  title = "Spearman Correlations: Bug Categories vs. Project Attributes"
)
dev.off()


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

# ---- Step 11: Domain heatmap ----
z_scores$BugCategory <- factor(z_scores$BugCategory, levels = bug_order)
z_scores$Domain <- factor(z_scores$Domain, levels = domain_order)

pdf("output/domain_bug_heatmap_ordered.pdf", width = 9, height = 6)
ggplot(z_scores, aes(x = BugCategory, y = Domain, fill = Z)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(low = "blue", mid = "white", high = "red", midpoint = 0,
                       name = "Relative Frequency (z)") +
  theme_minimal(base_size = 10) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1),
        panel.grid = element_blank()) +
  labs(
    title = "Relative Prevalence of Bug Categories by Domain",
    x = "Bug Category", y = "Project Domain"
  )
dev.off()


# ---- Step 12: Bug x Bug correlations heatmap ----
# ---- Prepare numeric bug matrix for correlation ----
bug_corr_data <- bug_matrix %>%
  filter(!(Project %in% c("Mean", "Total"))) %>%   # remove summary rows
  select(-Project) %>%                             # drop non-numeric columns
  mutate_all(as.numeric)                           # ensure all columns numeric

# ---- Compute Spearman correlations ----
bug_corr <- cor(bug_corr_data, method = "spearman", use = "pairwise.complete.obs")

# ---- Optional: check structure ----
str(bug_corr)

# Heatmap
library(corrplot)
pdf("output/bug_category_correlations_heatmap.pdf", width = 6, height = 6)
corrplot(bug_corr, method = "color", type = "lower",
         tl.col = "black", tl.srt = 45,
         col = colorRampPalette(c("blue", "white", "red"))(200),
         title = "Correlations Among Bug Categories")
dev.off()

# Network (optional)
library(igraph)
edges <- as.data.frame(as.table(bug_corr))
edges <- edges %>% filter(Var1 != Var2, abs(Freq) > 0.4)
g <- graph_from_data_frame(edges, directed = FALSE)
pdf("output/bug_category_correlation_network.pdf", width = 6, height = 6)
plot(g, vertex.size = 30, vertex.label.cex = 0.8,
     edge.width = abs(E(g)$Freq)*5,
     edge.color = ifelse(E(g)$Freq > 0, "firebrick", "steelblue"))
dev.off()



# ---- Step 13: Bug x tooling subcategories correlations ----

# ---- Visualization: Heatmap of dependency-category correlations (ordered, clean) ----

library(ggplot2)
library(dplyr)

# Define your final bug category order (consistent with RQ1)
bug_order <- c(
  "Async / Event",
  "Error Handling",
  "Missing Case",
  "Missing Feature",
  "Runtime Exception",
  "Tooling / Config",
  "Type Error",
  "Logic Error",
  "API Misuse",
  "Test Fault",
  "UI Bug"
)

# Manually shorten or add line breaks to long dependency category labels
results_cat <- results_cat %>%
  mutate(Category = recode(Category,
                           "Build Scripts & CI/CD Configuration" = "Build Scripts\n& CI/CD",
                           "Compiler & Build Target Configuration" = "Compiler &\nBuild Targets",
                           "Platform & Runtime Configuration" = "Platform &\nRuntime Config",
                           "External Tool Integration" = "External Tool\nIntegration",
                           "Dependency & Package Management" = "Dependency\nManagement"
  ))

# Filter out Total_Bugs if it exists
top_cats_ordered <- results_cat %>%
  filter(abs(Rho) > 0.3, BugCategory %in% bug_order) %>%
  mutate(
    BugCategory = factor(BugCategory, levels = bug_order)
  )

# Plot heatmap with consistent ordering
pdf("output/rq2c.pdf", width = 8, height = 4)
ggplot(top_cats_ordered, aes(x = BugCategory, y = Category, fill = Rho)) +
  geom_tile(color = "white") +
  scale_fill_gradient2(
    low = "#2166AC",
    mid = "white",
    high = "#B2182B",
    midpoint = 0,
    limits = c(-1, 1),   # clamp for more contrast (adjust if needed)
    name = "Spearman ρ"
  ) +
  theme_minimal(base_size = 16) +
  theme(
    axis.text.x = element_text(angle = 35, hjust = 0.85, margin = margin(t = 0, r = 0, b = -15, l = 0, unit = "pt")),
    axis.title.x = element_text(face = "bold"),
    axis.title.y = element_text(face = "bold"),
    panel.grid = element_blank()
  ) +
  labs(
#    title = "Correlation Between Dependency Categories and Bug Categories",
    x = "Bug Category",
    y = "Dependency Category"
  )
dev.off()



# ============================================================
# ---- Step 14: Completion summary ----
# ============================================================

cat("\n=== RQ2 Correlation and Domain Visualization Complete ===\n")
cat("Outputs written to output/:\n")
cat(" - rq2_correlations_heatmap.pdf\n")
cat(" - domain_bug_heatmap_ordered.pdf\n")
cat(" - rq2_correlations_matrix.csv\n")
cat(" - rq2_domain_kw_results.csv\n")
