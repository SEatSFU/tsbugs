# ---- Step 1: Load required packages ----
if (!require("tidyr")) install.packages("tidyr")
if (!require("dplyr")) install.packages("dplyr")

library(tidyr)
library(dplyr)

setwd("PLEASE SET THE PATH TO YOUR WORKING DIRECTORY (WHICH CONTAINS DATA, SCRIPTS, AND OUTPUT DIRECTORIES")


# ---- Step 2: Read the CSV file ----
bugs <- read.csv("data/bugs.csv",
                 header = TRUE, sep = ",")

# ---- Step 2.5: Map CSV bug labels to LaTeX labels ----
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

# Trim whitespace and apply mapping
bugs$Bug.Type <- trimws(bugs$Bug.Type)
bugs$Bug.Type <- ifelse(bugs$Bug.Type %in% names(label_map),
                        label_map[bugs$Bug.Type],
                        bugs$Bug.Type)

# ---- Step 3: Check column names ----
print(names(bugs))

# ---- Step 3.5: Integrate project metadata for domain and size ordering ----
projects <- read.csv("data/projects.csv",
                     header = TRUE, sep = ",")
projects$Project <- trimws(tolower(projects$Project))
bugs$Project.Name <- trimws(tolower(bugs$Project.Name))

# Identify LOC column dynamically
loc_col <- grep("Size", colnames(projects), value = TRUE)[1]

# Merge only Domain + LOC
projects_meta <- projects %>%
  select(Project, Domain, LOC = all_of(loc_col)) %>%
  mutate(Domain = trimws(Domain)) %>%
  distinct()

# ---- Step 3.5: Integrate project metadata for domain and size ordering (clean join) ----
projects <- read.csv("data/projects.csv",
                     header = TRUE, sep = ",")

# Normalize names for matching
normalize_name <- function(x) {
  x <- tolower(trimws(x))
  x <- gsub("[^a-z0-9\\-]", "", x)  # keep only alphanum + hyphen
  x
}

projects$Project_clean <- normalize_name(projects$Project)
bugs$Project_clean <- normalize_name(bugs$Project.Name)

# Detect LOC column dynamically (matches “Size”)
loc_col <- grep("Size", colnames(projects), value = TRUE)[1]

# Keep only relevant metadata
projects_meta <- projects %>%
  select(Project_clean, Domain, LOC = all_of(loc_col)) %>%
  mutate(Domain = trimws(Domain)) %>%
  distinct()

# Join domains/LOC into bug data for verification
bugs <- bugs %>%
  left_join(projects_meta, by = "Project_clean")

# Debug check for unmatched projects
unmatched <- bugs %>% filter(is.na(Domain)) %>% distinct(Project.Name)
if (nrow(unmatched) > 0) {
  cat("\n Warning: These projects had no domain match:\n")
  print(unmatched)
} else {
  cat("\n All projects matched to metadata successfully.\n")
}

# Compute project order (group by domain, sort by LOC desc)
project_order_df <- projects_meta %>%
  arrange(Domain, desc(as.numeric(LOC))) %>%
  filter(Project_clean %in% unique(bugs$Project_clean))

project_order <- unique(project_order_df$Project_clean)
cat("\n Project order (by domain, size):\n")
print(project_order)


# ---- Step 4: Summarize counts per project and bug type ----
bug_summary <- bugs %>%
  filter(!is.na(Project.Name), Project.Name != "",
         !is.na(Bug.Type), Bug.Type != "") %>%     # remove invalid project/bug entries
  group_by(Project = Project.Name, BugType = Bug.Type) %>%
  summarise(Count = n(), .groups = "drop")

# Debug check: confirm no NA projects or bug types remain
cat("\n Bug summary created. Unique projects:", length(unique(bug_summary$Project)), "\n")
if (any(is.na(bug_summary$Project)) | any(is.na(bug_summary$BugType))) {
  cat(" Warning: NA project or bug types remain!\n")
  print(bug_summary %>% filter(is.na(Project) | is.na(BugType)))
} else {
  cat(" No NA projects or bug types detected.\n")
}


# ---- Step 5: Pivot to wide format ----
bug_matrix <- bug_summary %>%
  pivot_wider(names_from = BugType, values_from = Count, values_fill = 0)

# ---- Step 6: Define consistent bug order (conceptual clusters) ----
cluster_integration <- c("Async / Event", "Error Handling", "Missing Case", "Missing Feature", "Runtime Exception")
cluster_toolchain <- c("Tooling / Config", "Type Error")
cluster_logic <- c("Logic Error", "API Misuse")
cluster_surface <- c("Test Fault", "UI Bug")
bug_order <- c(cluster_integration, cluster_toolchain, cluster_logic, cluster_surface)

# Ensure consistent column order
expected_cols <- c("Project", bug_order)
for (col in expected_cols[-1]) {
  if (!col %in% names(bug_matrix)) bug_matrix[[col]] <- 0
}
bug_matrix <- bug_matrix[, expected_cols]

# ---- Step 7: Domain + size ordering for projects ----
project_order_df <- projects_meta %>%
  arrange(Domain, desc(as.numeric(LOC))) %>%
  filter(Project_clean %in% unique(bugs$Project_clean))

project_order <- unique(project_order_df$Project_clean)
cat("\n Project order (by domain, size):\n")
print(project_order)

# Reorder projects in bug_matrix (use same normalized key)
bug_matrix$Project_clean <- normalize_name(bug_matrix$Project)
bug_matrix <- bug_matrix %>%
  mutate(Project = factor(Project_clean, levels = project_order)) %>%
  arrange(Project) %>%
  select(-Project_clean)


# ---- Step 8: Add total bugs per project ----
bug_matrix$`Total Bugs` <- rowSums(bug_matrix[, -1])

# ---- Step 9: Compute totals and means ----
numeric_part <- bug_matrix[, -1]
totals <- colSums(numeric_part)
means  <- colMeans(numeric_part)

# ---- Step 10: Add summary rows ----
bug_matrix <- rbind(bug_matrix,
                    c("Mean", round(means, 2)),
                    c("Total", totals))

# ---- Step 11: Generate LaTeX table ----
output_file <- "output/bug-frequencies.tex"

latex_header <- "\\begin{table*}[ht]
\\centering
\\caption{Bug Category Distribution Across Analyzed TypeScript Projects}
\\label{tab:bug_frequencies}
\\resizebox{\\textwidth}{!}{%
\\begin{tabular}{lrrrrrrrrrrrr}
\\toprule
\\textbf{Project} &
\\textbf{Async / Event} &
\\textbf{Error Handling} &
\\textbf{Missing Case} &
\\textbf{Missing Feature} &
\\textbf{Runtime Exception} &
\\textbf{Tooling / Config} &
\\textbf{Type Error} &
\\textbf{Logic Error} &
\\textbf{API Misuse} &
\\textbf{Test Fault} &
\\textbf{UI Bug} &
\\textbf{Total Bugs} \\\\
\\midrule
"

latex_footer <- "\\bottomrule
\\end{tabular}
}
\\end{table*}
"

# ---- Step 12: Write rows ----
format_row <- function(row) paste(row, collapse = " & ")
latex_rows <- apply(bug_matrix, 1, function(r) paste(format_row(r), "\\\\"))
latex_body <- paste(latex_rows, collapse = "\n")

# ---- Step 13: Write full table to file ----
cat(latex_header, latex_body, "\n", latex_footer, file = output_file)
cat("LaTeX table written to:", output_file, "\n")

# ---- Step 14: Visualization ----
if (!require("ggplot2")) install.packages("ggplot2")
library(ggplot2)

# Prepare data for plotting
plot_data <- bug_matrix %>%
  filter(!(Project %in% c("Mean", "Total")), !is.na(Project)) %>%   # remove summary + NA rows
  select(-`Total Bugs`) %>%
  pivot_longer(
    cols = -Project,
    names_to = "BugType",
    values_to = "Count"
  ) %>%
  filter(!is.na(BugType), BugType != "") %>%                        # remove NA columns
  mutate(Count = as.numeric(Count))


# Apply ordering
plot_data$Project <- factor(plot_data$Project, levels = project_order)
plot_data$BugType <- factor(plot_data$BugType, levels = bug_order)


# ---- Step 15: Stacked bar chart ----
p <- ggplot(plot_data, aes(x = BugType, y = Count, fill = Project)) +
  geom_bar(stat = "identity", position = "stack", width = 0.7) +
#  scale_fill_viridis_d(option = "turbo") +
#  scale_fill_viridis_d(option = "Set3") +
#  scale_fill_viridis_d(option = "plasma") +  # more contrast, warmer
#   scale_fill_viridis_d(option = "cividis") + # very clear, accessible, neutral
#   scale_fill_viridis_d(option = "magma") +   # dark-to-light, great on light backgrounds
#    scale_fill_viridis_d(option = "Harmonic") + # vivid reds and golds
  scale_fill_viridis_d(option = "Spectral", direction = -1) + # vivid reds and golds
  theme_minimal(base_size = 8) +
  theme(
    axis.text.x = element_text(size = 8, angle = 35, hjust = 0.72, margin = margin(t = 0, r = 0, b = -18, l = 0, unit = "pt")),
    legend.position = "right",
#    legend.title = element_text(face = "bold"),
    panel.grid.major.x = element_blank(),
    legend.key.size = unit(0.3, "cm"),
    axis.text.y = element_text(size = 8),
    axis.title = element_text(size = 8), #, face = "bold"),
    legend.title = element_text(size = 8, margin = margin(t = 10, b = 5)),
    legend.text = element_text(size = 8)
#    plot.title = element_text(size = 13, face = "bold", hjust = 0.5)
  ) +
  labs(x = "Bug Category", y = "Number of Bugs", fill = "Project")


output_plot <- "output/rq1-1-Spectral-bug-frequencies-stacked.pdf"
ggsave(output_plot, p, width = 7, height = 2.45)
cat("Stacked bar chart saved to:", output_plot, "\n")

# ---- Step 16: Normalized stacked area chart ----
plot_data_area <- plot_data %>%
  group_by(Project) %>%
  mutate(Proportion = Count / sum(Count, na.rm = TRUE)) %>%
  ungroup() %>%
  arrange(Project, BugType)

p_area_norm <- ggplot(plot_data_area,
                      aes(x = Project, y = Proportion, fill = BugType, group = BugType)) +
  geom_area(position = "stack", alpha = 0.9, color = "black", linewidth = 0.1) +
#  scale_fill_viridis_d(option = "turbo") +
#  scale_fill_viridis_d(option = "cividis") +
#  scale_fill_brewer(palette = "Paired")
#  scale_fill_brewer(palette = "Set3")
  scale_fill_brewer(palette = "Spectral", direction = -1) + # diverging, but visually striking
  scale_y_continuous(labels = percent_format(accuracy = 1)) +
  theme_minimal(base_size = 8) +
  theme(
    axis.text.x = element_text(size = 8, angle = 35, hjust = 0.72, margin = margin(t = 0, r = 0, b = -18, l = 0, unit = "pt")),
    legend.position = "right",
    legend.title = element_text(size = 8, margin = margin(t = 26, b = 5)),
    legend.text = element_text(size = 8),
    legend.key.size = unit(0.3, "cm"),
    axis.text.y = element_text(size = 8),
    panel.grid.major.x = element_blank(),
    panel.grid.minor = element_blank()
  ) +
  labs(x = "Project", y = "Bug Distribution (%)", fill = "Bug Category")

output_plot_area_norm <- "output/rq1-2-Spectral-bug-frequencies-area-normalized.pdf"
ggsave(output_plot_area_norm, p_area_norm, width = 7, height = 1.7)
cat("Normalized stacked area chart saved to:", output_plot_area_norm, "\n")
