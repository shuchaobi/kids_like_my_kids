kids_like_my_kids <- function()
{
  library(RPostgreSQL);
  con <- dbConnect(PostgreSQL(), user="bibudh", host="199.91.168.116", 
                   port="5438", dbname="casebook2_production");

  statement <- paste("select klmk_metrics_copy.*,",
                      " (select case_plan_focus_children.permanency_goal",
                      " from case_plan_focus_children, case_plans",
                      " where klmk_metrics_copy.child_id = case_plan_focus_children.person_id",
                      " and case_plan_focus_children.case_plan_id = case_plans.id",
                      " order by start_on ",
                      " limit 1) as first_perm_goal,",
                      " (re.end_date - re.start_date) as length_of_stay,",
                      " case when people.gender = 'Male' then 1",
                      " when people.gender = 'Female' then 0 ",
                      " else null ",
                      " end as gender,",
                      " extract(year from age(re.start_date, people.date_of_birth)) as age_in_years,",
                      " case when people.multi_racial = 't' then 1 else 0 ",
                      " end as multi_racial,",
                      " case when people.american_indian = 't' then 1 else 0 ",
                      " end as american_indian,",
                      " case when people.white = 't' then 1 else 0 ",
                      " end as white,",
                      " case when people.black = 't' then 1 else 0", 
                      " end as black,",
                      " case when people.pacific_islander = 't' then 1 else 0", 
                      " end as pacific_islander,",
                      " case when people.asian = 't' then 1 else 0", 
                      " end as asian",
                      " from klmk_metrics_copy, people, removal_episodes_copy re",
                      " where klmk_metrics_copy.child_id = people.id", 
                      " and re.child_id = klmk_metrics_copy.child_id ",
                      " and re.episode_number = klmk_metrics_copy.episode_number ",
                      " and re.end_date is not null",
                      sep = "");

  res <- dbSendQuery(con, statement);
  kid_metrics <- fetch(res, n = -1);

  kid_metrics$age_category <- apply(kid_metrics, 1, 
        function(row) categorize_age(as.numeric(row["age_in_years"])));

  if (FALSE)
  {
    kid_10000008184 <- subset(kid_metrics, (kid_metrics$child_id == 10000008184));
    kid_10000008453 <- subset(kid_metrics, (kid_metrics$child_id == 10000008453));

    cat(paste(compute_distance(kid_10000008184, kid_10000008453), "\n", sep = ""));
  }
  if (FALSE)
  {
    N_values <- c(1000, 5000, 20000);
    k_values <- c(100, 2000, 5000);
    alpha_values <- c(0.1, 0.2, 0.3);
    N <- nrow(kid_metrics);
    for (i in 1:3)
    {
      #fn <- find_kNN(kid_metrics[1, ], kid_metrics[2:(N_values[i] + 1), ], N_values[i], k_values[i]);
      find_NN_by_threshold(kid_metrics[1, ], kid_metrics[2:N, ], N = N, alpha = alpha_values[i]);
    }
  }
  if (FALSE)
  {
    my_kids <- c(10000008184, 10000008453, 10000009076, 10000010086, 
               10000010559, 10000011200, 10000011887, 10000012377,
               10000012932, 10000013642, 10000014664);

    for (i in 1:11)
    {
     find_NN_by_threshold_with_precomputed_distance(con, my_kids[i], 0.05);
    }
  }
  #return(fn);
  #histograms_by_dimensions(kid_metrics);
  find_clusters(kid_metrics);
  dbDisconnect(con);
}

  categorize_age <- function(age_in_years)
  {
    #cat(paste("age_in_years = ", age_in_years, "\n", sep = ""));
    if (is.na(age_in_years))
    {
      return(-1);
    }
    if (age_in_years <= 1)
    {
      return(1);
    }
    else if ((age_in_years > 1) & (age_in_years <= 5))
    {
      return(2);
    }
    else if ((age_in_years > 5) & (age_in_years <= 10))
    {  
      return(3);
    }
    else if ((age_in_years > 10) & (age_in_years <=15))
    {
      return(4);
    }
    else
      return(5);
  }


#Compute the number of metrics on which two vectors have identical values, and 
#divide by the total number of metrics. A vector represents the combination of a child
#and a removal episode.
compute_distance <- function(child_1, child_2)
{
   if (FALSE)
   {
     covariates <- c("family_structure_single_female", "family_structure_single_male",
                   "family_structure_married_couple",
                   "family_structure_unmarried_couple",
                   "parent_alcohol_abuse",
                   "parent_drug_abuse",
                   "child_behavioral_problem",
                   "child_disability",
                   "case_county_id",
                   "assessment_county_id",
                   "primary_caregiver_has_mental_health_problem",
                   "domestic_violence_reported", 
                   "count_previous_removal_episodes",
                   "initial_placement_setting",
                   "gender", "age_category",
                   "multi_racial", "american_indian", 
                   "white", "black", "pacific_islander",
                   "asian");
   }
   #Checking the covariates that seem to have significant influence
   covariates <- c("age_category", "american_indian", "asian", "black", "child_disability",
                   "count_previous_removal_episodes", "family_structure_married_couple", 
                   "family_structure_single_female", "parent_alcohol_abuse",
                   "parent_drug_abuse", "white");
   n_covariates <- length(covariates);
   non_matching_covariates <- 0;
   both_have_values <- 0;

   for (i in 1:n_covariates)
   {
     #cat(paste(kid_metrics[1, covariates[i]], "\n", sep = ""));
     if ((!is.na(child_1[, covariates[i]])) & (!is.na(child_2[, covariates[i]]))) 
     {
       both_have_values <- both_have_values + 1;
       if  (child_1[, covariates[i]] != child_2[, covariates[i]])
       {
         #cat(paste("covariate = ", covariates[i], "\n", sep = ""));
         non_matching_covariates <- non_matching_covariates + 1;
       }
     }
   }
   if (both_have_values > 0)
   {
     #cat(paste("non_matching_covariates = ", non_matching_covariates, ", both_have_values = ",
     #          both_have_values, "\n", sep = ""));
     return(non_matching_covariates/both_have_values);
   }
   return(-1);
}

 find_kNN <- function(my_kid, other_kids, N, k)
 {
   n_other_kids <- nrow(other_kids);
   for (i in 1:n_other_kids)
   {
     other_kids[i, "distance_with_my_kid"] <- compute_distance(my_kid, other_kids[i,]);
   }
   other_kids <- other_kids[order(other_kids[,"distance_with_my_kid"]),];
   k_most_similar_kids <- other_kids[1:k, ];
   cat(paste("LoS for my kid = ", my_kid[, "length_of_stay"], "\n", sep = ""));
   cat(paste("LoS of most similar kids", "\n", sep = ""));
   print(cbind(other_kids[, "distance_with_my_kid"], other_kids[, "length_of_stay"]));
   cat("summary\n");
   descriptive_nums <- histogram_for_similar_kids(k_most_similar_kids, N = N, k = k); 
   return(descriptive_nums);

}


   #Find the nearest kids to a given kid who have distance within alpha, and
   #plot the histograms of LoS for the other kids, and compare with my kid.

  find_NN_by_threshold <- function(my_kid, other_kids, N, alpha)
 {
   cat(paste("N = ", N, ", alpha = ", alpha, "\n", sep = ""));
   n_other_kids <- nrow(other_kids);
   for (i in 1:n_other_kids)
   {
     other_kids[i, "distance_with_my_kid"] <- compute_distance(my_kid, other_kids[i,]);
     if (i%%100 == 0)
     {
       cat(paste("computed for ", i, " kids\n", sep = ""));
     }
   }
   most_similar_kids <- subset(other_kids, (other_kids$distance_with_my_kid <= alpha));
   cat(paste("LoS for my kid = ", my_kid[, "length_of_stay"], "\n", sep = ""));
   #cat(paste("LoS of most similar kids", "\n", sep = ""));
   #print(cbind(other_kids[, "distance_with_my_kid"], other_kids[, "length_of_stay"]));
   descriptive_nums <- histogram_for_similar_kids(most_similar_kids, N = N, alpha = alpha); 
   return(descriptive_nums);
 }


  histogram_for_similar_kids <- function(my_kid, k_most_similar_kids, N, k, alpha)
  {
   descriptive_nums <- fivenum(k_most_similar_kids$length_of_stay);
   if (!is.na(k))
   {
    filename <- paste("./LoS_for_similar_kids/length_of_stay_histogram_", my_kid, "_", N, "_", k, ".png", sep = "");
   }
   if (!is.na(alpha))
   {
    filename <- paste("./LoS_for_similar_kids/length_of_stay_histogram_",  my_kid, "_", N, "_", alpha, ".png", sep = "");
   }
   #cat(paste("max = ", max(k_most_similar_kids$length_of_stay)));

   png(filename,  width = 920, height = 960, units = "px");
   truncated_data <- subset(k_most_similar_kids, (k_most_similar_kids$length_of_stay <= 2000));
   #edges <- c(0, 120, 240, 360, 480, 600, 720, 840, 960, 1080, 1200, 1500, 2000, 3000, 6000, 8000);
   edges <- seq(0, 2040, by = 120);
   histogram <- hist(truncated_data$length_of_stay, 
                     breaks = edges, 
                     plot = FALSE);
   customHistogram(histogram = histogram, 
         mainTitle = "Distribution of LoS among kids like my kid",
         xLabel = "length in days", yLabel = "Fraction of children",
         descriptive_nums);
   dev.off();
   return(descriptive_nums);
  }

customHistogram <- function(histogram, mainTitle, xLabel,
                            yLabel, fiveNumberSummary, 
                            queryPoint = as.character(Sys.Date()))
{
  #If there are n bars in the histogram, then 
  #histogram$breaks is an array of (n+1) points, including
  #the start-point of first bucket and last point of last bucket.
  #histogram$counts is an array of n numbers.
  nBars <- length(histogram$counts);
  totalFreq <- sum(histogram$counts);
  heights <- histogram$counts/totalFreq;
  widths <- c();
  barLabels <- c();
  xAxisRightEnd <- max(histogram$breaks);
  width <- ceiling(xAxisRightEnd/nBars);
  for (i in 1:nBars)
  {
    widths[i] <- width;
    #barLabels[i] <- as.character(histogram$breaks[i+1]);
    leftPoint <- 0;
    if (i > 1)
    {
      leftPoint <- histogram$breaks[i] + 1; 
    }
    barLabels[i] <- paste(as.character(leftPoint),
                          "-",
                          as.character(histogram$breaks[i+1]));
  }
 
 subTitle <- paste("Q1 = ", round(fiveNumberSummary[2]),
                    ", Median = ", round(fiveNumberSummary[3]),
                    ", Q3 = ", round(fiveNumberSummary[4]),
                    sep = "");
  barplot(height = heights, width = widths, xlim = c(0, xAxisRightEnd),
          beside = TRUE, horiz = FALSE, main = mainTitle, xlab = xLabel,
          ylab = yLabel, cex.lab = 1.5, space = 0, axisnames = TRUE, cex.names = 1.5,
          cex.axis = 1.5, cex.main = 1.5, col.main= "blue",
          names.arg = barLabels, 
          sub = subTitle, cex.sub = 1.5, col.sub = "red"
          );
}

  #Histograms to check what dimensions are important
  histograms_by_dimensions <- function(kid_metrics)
  {
     covariates <- c("family_structure_single_female", "family_structure_single_male",
                   "family_structure_married_couple",
                   "family_structure_unmarried_couple",
                   "parent_alcohol_abuse",
                   "parent_drug_abuse",
                   "child_behavioral_problem",
                   "child_disability",
                   "case_county_id",
                   "assessment_county_id",
                   "primary_caregiver_has_mental_health_problem",
                   "domestic_violence_reported", 
                   "count_previous_removal_episodes",
                   "initial_placement_setting",
                   "gender", "age_category",
                   "multi_racial", "american_indian", 
                   "white", "black", "pacific_islander",
                   "asian");
      n_covariates <- length(covariates);
      for (i in 1:n_covariates)
      {
          cat(paste("covariate = ", covariates[i], "\n", sep = ""));
          filename <- paste("./histograms_by_dimensions/length_of_stay_by_", covariates[i],".png", sep = "");
          png(filename,  width = 920, height = 960, units = "px");
          distinct_values <- unique(kid_metrics[, covariates[i]]);
          distinct_values <- distinct_values[!is.na(distinct_values)];
          n_distinct_values <- min(5, length(distinct_values));
          cat(paste("n_distinct_values = ", n_distinct_values, "\n", sep = ""));
          if (n_distinct_values > 0)
          {
            par(mfrow=c(n_distinct_values, 1));
            for (j in 1:n_distinct_values)
            {
              cat(paste("covariate = ", covariates[i], ", value = ", distinct_values[j], "\n", sep = ""));
              kid_metrics_this_value <- subset(kid_metrics, (kid_metrics[, covariates[i]] == distinct_values[j]));
              cat(paste("nrow = ", nrow(kid_metrics_this_value), ", ncol = ",
                        ncol(kid_metrics_this_value), "\n", sep = ""));
              histogram <- hist(kid_metrics_this_value$length_of_stay, 
                                    plot = FALSE);
              customHistogram(histogram = histogram, 
                               mainTitle = paste("LoS for ", nrow(kid_metrics_this_value), 
                                                 " children with ", covariates[i], " = ", distinct_values[j], sep = ""),
                               xLabel = "length in days", yLabel = "Fraction of children",
                               fivenum(kid_metrics_this_value$length_of_stay));
            }
          }
          dev.off();
      }
  }

 

  #For a number K, take a random sample of K (child, removal episode) combinations as the test data.
  #All the remaining data are training data. For each (child, removal episode) combination in the test data,
  #take the k nearest neighbors from the test (child, removal episode) combinations, check the median LoS
  #of the k NNs, and then find the difference of the median LoS with the LoS of the test kid. 


  #Using precomputed distances from the DB. 
  find_NN_by_threshold_with_precomputed_distance <- function(con, my_kid, alpha)
  {
     cat(paste("alpha = ", alpha, "\n", sep = ""));
     statement <- paste("select (re1.end_date - re1.start_date) length_of_stay ",
                        " from pairwise_distances_copy, removal_episodes_copy re1 ",
                        " where (child_id_2 = re1.child_id) ",
                        " and (child_id_1 = ", my_kid, ")",
                        " and (distance >= 0 and distance <= ", alpha, ")",
                        " union",
                        " select (re2.end_date - re2.start_date) length_of_stay",
                        " from pairwise_distances_copy, removal_episodes_copy re2",
                        " where (child_id_1 = re2.child_id)",
                        " and (child_id_2 = ", my_kid, ")",
                        " and (distance >= 0 and distance <= ", alpha, ")", sep = "");
     res <- dbSendQuery(con, statement);
     similar_kids <- fetch(res, n = -1);
     most_similar_kids <- subset(similar_kids, !is.na(similar_kids$length_of_stay));
     descriptive_nums <- histogram_for_similar_kids(my_kid, most_similar_kids, N = nrow(most_similar_kids), 
                         k = NA, alpha = alpha); 
     fit1 <- survival_for_similar_kids(my_kid, most_similar_kids, N = nrow(most_similar_kids), alpha);
     find_most_likely_LoS_value(fit1, 30);
     #return(descriptive_nums);
     return(fit1);
  }


   survival_for_similar_kids <- function(my_kid, k_most_similar_kids, N, alpha)
  {
    library(survival);
    filename <- paste("./LoS_for_similar_kids/length_of_stay_survival_", my_kid, "_", 
                       N, "_", alpha, ".png", sep = "");
   #cat(paste("max = ", max(k_most_similar_kids$length_of_stay)));

   png(filename,  width = 920, height = 960, units = "px");
   fit1 <- survfit(Surv(length_of_stay)~1, data = k_most_similar_kids,
                     type = 'kaplan-meier');
   #print(summary(fit1));
   plot(fit1);
   dev.off();
   return(fit1);
  }

  find_most_likely_LoS_value <- function(survival_object, stepsize)
  {
    n_time_points <- length(survival_object$time);
    start_index <- 1;
    end_index <- start_index + stepsize - 1;
   
    max_slope <- 0;
    start_time_max_slope <- 0;
    end_time_max_slope <- 0;
  
    while (end_index <= n_time_points)
    {
      start_time <- survival_object$time[start_index];
      end_time <- survival_object$time[end_index];
      start_probability <- survival_object$surv[start_index];
      end_probability <- survival_object$surv[end_index];

      local_slope <- round((start_probability - end_probability)/(end_time - start_time), 4);
      if (local_slope > max_slope)
      {
        max_slope <- local_slope;
        start_time_max_slope <- start_time;
        end_time_max_slope <- end_time;
      }
      if (FALSE)
      {
        cat(paste("start_index = ", start_index, ", end_index = ", end_index, 
                  ", start_time = ", start_time, ", end_time = ", end_time,
                  ", start_probability = ", start_probability, 
                  ", end_probability = ", end_probability,  
                  ", local_slope = ", local_slope, ", max_slope = ", 
                  max_slope, "\n", sep = ""));
      }
      start_index <- end_index + 1;
      end_index <- start_index + stepsize - 1;

      #cat(paste("start_index = ", start_index, ", end_index = ", end_index, "\n", sep = ""));
    }
    most_likely_LoS_value <- (start_time_max_slope + end_time_max_slope)/2;
    #cat(paste("most_likely_LoS_value = ", most_likely_LoS_value, "\n", sep = ""));
    return(most_likely_LoS_value);
  }


  generate_summary_statistics <- function()
  {
     library(RPostgreSQL);
     library(survival);
     con <- dbConnect(PostgreSQL(), user="bibudh", host="199.91.168.116", 
                   port="5438", dbname="casebook2_production");
     statement <- paste("select distinct child_id_1 my_kid_id, episode_number_1, ",
                        "(removal_episodes_copy.end_date - removal_episodes_copy.start_date) actual_los ",
                        "from pairwise_distances_copy, removal_episodes_copy ",
                        "where pairwise_distances_copy.child_id_1 = removal_episodes_copy.child_id ",
                        "and pairwise_distances_copy.episode_number_1 = removal_episodes_copy.episode_number ",
                        "order by child_id_1, episode_number_1", sep = "");
      res <- dbSendQuery(con, statement);
      my_kids <- fetch(res, n = -1);
      #print(my_kids);
      n_my_kids <- nrow(my_kids);
      summary_columns <- c("my_kid", "actual_los", "Q1_similar_kids",
                           "median_similar_kids", "Q3_similar_kids", "most_likely_los");
      #summary_statistics <- mat.or.vec(n_my_kids, length(summary_columns));
      #summary_statistics <- data.frame(matrix(nrow= n_my_kids, 
      #                                  ncol = length(summary_columns)));
      summary_statistics <- data.frame();
      alpha <- 0.1;
      for (i in 1:n_my_kids)
      {
        my_kid <- my_kids[i, "my_kid_id"];
        statement <- paste("select (re1.end_date - re1.start_date) length_of_stay ",
                        " from pairwise_distances_copy, removal_episodes_copy re1 ",
                        " where (child_id_2 = re1.child_id) ",
                        " and (child_id_1 = ", my_kid, ")",
                        " and (distance >= 0 and distance <= ", alpha, ")",
                        " union",
                        " select (re2.end_date - re2.start_date) length_of_stay",
                        " from pairwise_distances_copy, removal_episodes_copy re2",
                        " where (child_id_1 = re2.child_id)",
                        " and (child_id_2 = ", my_kid, ")",
                        " and (distance >= 0 and distance <= ", alpha, ")", sep = "");
       res <- dbSendQuery(con, statement);
       similar_kids <- fetch(res, n = -1);

       most_similar_kids <- subset(similar_kids, !is.na(similar_kids$length_of_stay));
       descriptive_nums <- fivenum(most_similar_kids$length_of_stay);

       fit1 <- survfit(Surv(length_of_stay)~1, data = most_similar_kids,
                     type = 'kaplan-meier');
 
       if (FALSE)
       {
         summary_statistics[i, "my_kid"] <- my_kid;
         cat(paste(summary_statistics[i, "my_kid"], "\n", sep = ""));
         

         summary_statistics[i, "actual_LoS"] <- as.numeric(my_kids[i, "actual_LoS"]);
         summary_statistics[i, "Q1_similar_kids"] <- descriptive_nums[2];
         summary_statistics[i, "median_similar_kids"] <- descriptive_nums[3];
         summary_statistics[i, "Q3_similar_kids"] <- descriptive_nums[4];
         summary_statistics[i, "most_likely_LoS"] <- find_most_likely_LoS_value(fit1, 30);
       }
       #cat(paste(my_kids[i, "actual_LoS"], "\n", sep = ""));
       row <- c(my_kid, my_kids[i, "actual_los"], descriptive_nums[2], descriptive_nums[3],
                descriptive_nums[4], find_most_likely_LoS_value(fit1, 30));
       summary_statistics <- rbind(summary_statistics, row);
      }
      colnames(summary_statistics) <- summary_columns;
      
      measure_relative_errors(summary_statistics);
      dbDisconnect(con);
  }
 

  measure_relative_errors <- function(summ_stats)
  {
    summ_stats$relative_error_for_Q1 <- 
       abs((summ_stats$actual_los - summ_stats$Q1_similar_kids)/summ_stats$actual_los);

    summ_stats$relative_error_for_median <- 
       abs((summ_stats$actual_los - summ_stats$median_similar_kids)/summ_stats$actual_los);

    summ_stats$relative_error_for_Q3 <- 
       abs((summ_stats$actual_los - summ_stats$Q3_similar_kids)/summ_stats$actual_los);
    print(summ_stats);

    cat(paste("median relative error from Q1 = ", 
               round(median(summ_stats$relative_error_for_Q1), 3), 
               ", median relative error from median = ", 
               round(median(summ_stats$relative_error_for_median), 3),
               ", median relative error from Q3 = ", 
               round(median(summ_stats$relative_error_for_Q3), 3), "\n", sep = ""));
  }

  find_clusters <- function(kid_metrics)
  {
    library(klaR);
    covariates <- c("age_category", "american_indian", "asian", "black", "child_disability",
                   "count_previous_removal_episodes", "family_structure_married_couple", 
                   "family_structure_single_female", "parent_alcohol_abuse",
                   "parent_drug_abuse", "white");
    kid_metrics <- kid_metrics[, covariates];
    cat(paste("nrow(kid_metrics) = ", nrow(kid_metrics), ", ncol(kid_metrics) = ",
              ncol(kid_metrics), "\n", sep = ""));
    cl <- kmodes(kid_metrics, 5, iter.max = 3);
    plot(jitter(kid_metrics), col = cl$cluster); 
  }
