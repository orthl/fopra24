library(ggplot2)
library(dplyr)  

data <- read.csv("E:/Desktop/FoPra_Sim experiment3_read-table.csv", 
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
                          "use_random_seed","seeing_prob","step", "adopter", "non-adopter", 
                          "moderate-interestet")

# Spalten wählen
data_selected <- data_clean[, c("run_number", "seeing_prob", "step", "adopter", "non-adopter", "moderate-interestet")]

# Spalten in num-Werte
data_selected[] <- lapply(data_selected, function(x) as.numeric(as.character(x)))

# Daten gruppieren und summieren
data_summarized <- aggregate(cbind(adopter, `non-adopter`, `moderate-interestet`) ~ seeing_prob + step, 
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
ggplot(data_filtered, aes(x = step, y = adopter, color = factor(seeing_prob), linetype = factor(seeing_prob))) +
  geom_line(size = 2.5) +
  labs(title = "ID mit unterschiedlicher Lese Wahr.",
       x = "Step",
       y = "Adaptierer",
       color = "Lese Wahr.",
       linetype = "Lese Wahr.") +
  theme_minimal(base_size = 54)

# Ausgabe der Step 400
cat("Dateiname:", dateiname, "\n")
value_at_step_400

