# source('R/packages.R')
# source('R/functions.R')
source('R/0320-tables-phase2.R')


##proces the fsih data for upstream and downstream of crossings
##where sampling occurred

hab_fish_indiv_prep <- habitat_confirmations %>%
  purrr::pluck("step_3_individual_fish_data") %>%
  dplyr::filter(!is.na(site_number)) %>%
  select(-gazetted_names:-site_number)

hab_fish_indiv_prep2 <- left_join(
  hab_fish_indiv_prep,
  hab_loc,
  by = 'reference_number'
)


hab_fish_indiv_prep3 <- left_join(
  hab_fish_indiv_prep2,
  select(hab_fish_codes, common_name:species_code),
  by = c('species' = 'common_name')
) %>%
  dplyr::select(reference_number, alias_local_name, site_number, sampling_method, method_number, species_code, length_mm) ##added method #


##we need the size of the sites too

####workflow is a bit weird because we need to input NFC sites and the size of the sites
##or else we don't know about them in the summary.
# hab_fish_collect_prep <- habitat_confirmations %>%
#   purrr::pluck("step_2_fish_coll_data") %>%
#   dplyr::filter(!is.na(site_number)) %>%
#   # select(-gazetted_name:-site_number) %>%
#   dplyr::distinct(reference_number, method_number, .keep_all = T) ##added method #
hab_fish_collect_prep_mt <- habitat_confirmations %>%
  purrr::pluck("step_2_fish_coll_data") %>%
  dplyr::filter(!is.na(site_number)) %>%
  tidyr::separate(local_name, into = c('site', 'location', 'ef'), remove = F) %>%
  mutate(site_id = paste0(site, location)) %>%
  distinct(local_name, sampling_method, method_number, .keep_all = T) %>% ##changed this to make it work as a feed for the extract-fish.R file
  mutate(across(c(date_in,date_out), janitor::excel_numeric_to_date)) %>%
  mutate(across(c(time_in,time_out), chron::times))

##we use this to test things out
# hab_fish_indiv <- left_join(
#   select(hab_fish_collect_prep_mt %>% filter(reference_number == 36),
#          reference_number,
#          local_name,
#          site_number:model, date_in:time_out ##added date_in:time_out
#   ),
#   select(hab_fish_indiv_prep3 %>% filter(reference_number == 36),
#          reference_number,
#          sampling_method,
#          method_number, ##added method #
#          # alias_local_name,
#          species_code, length_mm),
#   by = c('reference_number', 'sampling_method', 'method_number') #added method # and haul
# )

##
hab_fish_indiv <- left_join(
   select(hab_fish_collect_prep_mt,
          reference_number,
          local_name,
          site_number:model, date_in:time_out ##added date_in:time_out
          ),
  select(hab_fish_indiv_prep3,
         reference_number,
         sampling_method,
         method_number, ##added method #
         # alias_local_name,
         species_code, length_mm),
  by = c('reference_number', 'sampling_method', 'method_number') #added method # and haul
) %>%
  mutate(species_code = as.character(species_code)) %>%
  mutate(species_code = case_when(
    is.na(species_code) ~ 'NFC',
    T ~ species_code)
  ) %>%
  mutate(species_code = as.factor(species_code))  %>%
  mutate(life_stage = case_when(  ##this section comes from the histogram below - we include here so we don't need to remake the df
    length_mm <= 70 ~ 'fry',
    length_mm > 70 & length_mm <= 100 ~ 'parr',
    length_mm > 100 & length_mm <= 140 ~ 'juvenile',
    length_mm > 140 ~ 'adult',
    T ~ NA_character_
  )) %>%
  mutate(life_stage = fct_relevel(life_stage,
                                  'fry',
                                  'parr',
                                  'juvenile',
                                  'adult')) %>%
  tidyr::separate(local_name, into = c('site', 'location', 'ef'), remove = F) %>%
  mutate(site_id = paste0(site, '_', location))

tab_fish_summary <- hab_fish_indiv %>%
  group_by(site_id, sampling_method, species_code) %>% ##added sampling method!
  summarise(count_fish = n())



###------from duncan_fish_plots_20200210

####----------fish length-----------
fish <- hab_fish_indiv
  # filter(species_code == "CO")
# fish_eb <-  hab_fish_indiv %>% filter(species_code != "EB")

bin_1 <- floor(min(fish$length_mm, na.rm = TRUE)/5)*5
bin_n <- ceiling(max(fish$length_mm, na.rm = TRUE)/5)*5
bins <- seq(bin_1,bin_n, by = 5)

plot_fish_hist <- ggplot(fish %>% filter(!species_code %in% c("MW",'SU','NFC', 'DV')),
                         aes(x=length_mm
                                          # fill=alias_local_name
                                         # color = alias_local_name
                                         )) +
  geom_histogram(breaks = bins, alpha=0.75,
                 position="identity", size = 0.75)+
  labs(x = "Fork Length (mm)", y = "Count (#)") +
  facet_wrap(~species_code)+
  # scale_color_grey() +
  # scale_fill_grey() +
  theme_bw(base_size = 8)+
  scale_x_continuous(breaks = bins[seq(1, length(bins), by = 2)])+
  # scale_color_manual(values=c("grey90", "grey60", "grey30", "grey0"))+
  theme(axis.text.x = element_text(angle = 45, hjust = 1))
  # geom_histogram(aes(y=..density..), breaks = bins, alpha=1,
  #                position="identity", size = 0.75)
# plot_fish_hist


# ggsave(plot = plot_fish_hist, file="./fig/fish_histogram.png",
#        h=3.4, w=5.11, units="in", dpi=300)

####-----------summary tables for input to spreadsheet----------------------
hab_fish_input_prep <- hab_fish_indiv %>%
  group_by(across(-contains('length_mm'))) %>%
  # group_by(reference_number:model, species_code, life_stage) %>%
  summarise(min = min(length_mm),
            max = max(length_mm),
            n = length(length_mm))
  # janitor::adorn_totals()


##need to add the species name
hab_fish_input <- left_join(
  hab_fish_input_prep,
  select(hab_fish_codes, common_name, species_code),
  by = 'species_code'
) %>%
  ungroup() %>%
  select(reference_number:time_out, common_name, stage = life_stage, total_number = n,
         min, max) %>%
  mutate(total_number = case_when(
    common_name == 'No Fish Caught' ~ NA_integer_,
    T ~ total_number
  ))
  # janitor::adorn_totals()   ##use this to ensure you have the same number of fish in the summary as the individual fish sheet

##burn to a csv so you can cut and paste into your fish submission
# hab_fish_input %>%
#   readr::write_csv(file = paste0(getwd(), '/data/extracted_inputs/hab_con_fish_summary.csv'),
#                    na = "")


######----------------density plots--------------------------

hab_fish_dens <- hab_fish_indiv %>%
  filter(sampling_method == 'electrofishing') %>% ##added this since we now have mt data as well!!
  mutate(area = round(ef_length_m * ef_width_m),0) %>%
  group_by(local_name, site_number, ef_length_m, ef_width_m, ef_seconds, area, species_code, life_stage) %>%
  summarise(fish_total = length(life_stage)) %>%
  ungroup() %>%
  mutate(density_100m2 = round(fish_total/area * 100, 1)) %>%
  tidyr::separate(local_name, into = c('site', 'location', 'ef'), remove = F) %>%
  mutate(site_id = paste0(site, location),
         location = case_when(location == 'us' ~ 'Upstream',
                              T ~ 'Downstream'),
         life_stage = factor(life_stage, levels = c('fry', 'parr', 'juvenile', 'adult')))

# hab_fish_dens %>%
#   readr::write_csv(file = paste0(getwd(), '/data/extracted_inputs/hab_fish_dens.csv'))

##paths to write to will need to change now
# ggsave(plot = plot_fish_box, filename = "./fig/plot_fish_box.png",
#        h=9.66, w=14.5, units="cm", dpi=300)

##clean up the workspace
remove <- ls() %>%
  stringr::str_subset(., 'prep|bin')

##this prints a list to the console that we can copy and paste into the rm call #https://stackoverflow.com/questions/30861769/convert-a-list-into-a-string/30862559
# paste(unlist(remove), collapse=', ')

rm(bin_1, bin_n, bins, hab_fish_collect_prep_mt, hab_fish_indiv_prep, hab_fish_indiv_prep2, hab_fish_indiv_prep3, hab_fish_input_prep)
