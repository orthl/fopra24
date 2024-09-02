library(ggplot2)
library(dplyr)  

data <- read.csv("E:/Desktop/FoPra_Sim experiment2-table.csv", 
                 skip = 6, 
                 header = TRUE, 
                 sep = ",")

dateiname <- basename("E:/Desktop/FoPra_Sim experiment1-table.csv")

# Alle " Zeichen entfernen
data_clean <- data.frame(lapply(data, function(x) gsub("\"", "", x)))

# Spaltennamen manuell setzen
colnames(data_clean) <- c("run_number", "sharing_prob", "commenting_prob", 
                          "unfollow_prob", "follow_prob", "rewiring_probability", 
                          "posts_frequency", "seed", "liking_prob", "num_nodes", 
                          "use_random_seed", "step", "adopter", "non-adopter", 
                          "moderate-interestet")

# Spalten wählen
data_selected <- data_clean[, c("run_number", "posts_frequency", "step", "adopter", "non-adopter", "moderate-interestet")]

# Spalten in num-Werte
data_selected[] <- lapply(data_selected, function(x) as.numeric(as.character(x)))

# Daten gruppieren und summieren
data_summarized <- aggregate(cbind(adopter, `non-adopter`, `moderate-interestet`) ~ `posts_frequency` + step, 
                             data = data_selected, 
                             FUN = mean)

colnames(data_selected)
head(data_selected)

# jeden 25. Step berücksichtigen
data_filtered <- data_summarized[data_summarized$step %% 25 == 0, ]

# Wert bei Step 400
value_at_step_400 <- data_filtered %>%
  filter(step == 400)

# Diagramm erstellen
ggplot(data_filtered, aes(x = step, y = adopter, color = factor(posts_frequency), linetype = factor(posts_frequency))) +
  geom_line(size = 2.5) +
  labs(title = "ID mit unterschiedlicher Anzahl an Posts",
       x = "Step",
       y = "Adaptierer",
       color = "Anz. Posts",
       linetype = "Anz. Posts") +
  theme_minimal(base_size = 54)

# Ausgabe der Step 400
cat("Dateiname:", dateiname, "\n")
value_at_step_400

