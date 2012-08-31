drop function if exists get_from_initial_placement_quiz(bigint, bigint, bigint);
create function get_from_initial_placement_quiz(bigint, bigint, bigint) returns void as $$
  declare
    v_child_id alias for $1;
    v_episode_number alias for $2;
    v_initial_placement_quiz_id alias for $3;

    v_single_female smallint;
    v_single_male smallint;
    v_married_couple smallint;
    v_unmarried_couple smallint;
    v_parent_alcohol_abuse boolean;
    v_parent_drug_abuse boolean;

  begin
    select ipq.parent_alcohol_abuse,
      ipq.parent_drug_abuse,
      ipq.child_behavioral_problem,
      ipq.child_disability,
      case when ipq.family_structure = 'Single Female' then 1 else 0
           end,
      case when ipq.family_structure = 'Single Male' then 1 else 0
           end,
      case when ipq.family_structure = 'Married Couple' then 1 else 0
           end,
      case when ipq.family_structure = 'Unmarried Couple' then 1 else 0
           end
      into v_parent_alcohol_abuse, v_parent_drug_abuse, v_single_female,
           v_single_male, v_married_couple, v_unmarried_couple
      from initial_placement_quizzes ipq where ipq.id = v_initial_placement_quiz_id;

      update klmk_metrics
      set family_structure_single_female = v_single_female,
      family_structure_single_male = v_single_male,
      family_structure_married_couple = v_married_couple,
      family_structure_unmarried_couple = v_unmarried_couple,
      parent_alcohol_abuse = v_parent_alcohol_abuse,
      parent_drug_abuse = v_parent_drug_abuse,

      where child_id = v_child_id
      and episode_number = v_episode_number;
  end;
$$ LANGUAGE plpgsql;

drop function if exists case_county_for_kids_like_my_kids(bigint, bigint);
CREATE FUNCTION case_county_for_kids_like_my_kids(bigint, bigint) returns void as $$
  declare
    v_child_id alias for $1;
    v_episode_number alias for $2;

    v_case_county bigint;
    v_assessment_county bigint;

  begin
    select cs.county_id, assessments.county_id into v_case_county, v_assessment_county
    from cases cs
     inner join case_plans cl on (cl.case_id = cs.id)
     inner join case_plan_focus_children cpfc on (cpfc.case_plan_id = cl.id) 
     inner join case_linked_assessments cla on (cla.case_id = cs.id) 
     inner join assessments on (cla.assessment_id = assessments.id)
     where cpfc.person_id = v_child_id;

    update klmk_metrics
    set case_county_id = v_case_county,
        assessment_county_id = v_assessment_county
    where child_id = v_child_id
    and episode_number = v_episode_number;
  end;
$$ LANGUAGE plpgsql;

drop function if exists from_abuse_quizzes(bigint, bigint);
create function from_abuse_quizzes(bigint, bigint) returns void as $$
  declare
    v_child_id alias for $1;
    v_episode_number alias for $2;

    v_primary_caregiver_has_mental_health_problem boolean;
    v_domestic_violence_reported boolean;

  begin
     select aq.n11, aq.n7
     into v_primary_caregiver_has_mental_health_problem, v_domestic_violence_reported
     inner join case_plan_focus_children cpfc on (cpfc.person_id = v_child_id)
     inner join case_plans cl on (cpfc.case_plan_id = cl.id) 
     inner join cases cs on (cl.case_id = cs.id)
     inner join case_linked_assessments cla on (cla.case_id = cs.id) 
     inner join assessments on (cla.assessment_id = assessments.id)
     inner join risk_assessments ra on (ra.assessment_id = assessments.id)
     inner join abuse_quizzes aq on (aq.risk_assessment_id = ra.id);

     update klmk_metrics
     set primary_caregiver_has_mental_health_problem = v_primary_caregiver_has_mental_health_problem,
        domestic_violence_reported = v_domestic_violence_reported
     where child_id = v_child_id
     and episode_number = v_episode_number;

  end;
$$ LANGUAGE plpgsql;

drop function if exists metrics_for_kids_like_my_kids();
CREATE FUNCTION metrics_for_kids_like_my_kids() RETURNS bigint AS $$
  declare
    age_in_years integer := 0;
    v_first_rem_loc_id bigint;
    v_initial_placement_quiz_id bigint;

    curKidsWithRemEps cursor for
      select re.child_id, re.episode_number, re.start_date, (re.end_date - re.start_date) length_of_stay
      from removal_episodes re
      order by re.child_id, re.episode_numer;

    begin
      for kid_with_rem_ep in curKidsWithRemEps loop
     
        insert into klmk_metrics (child_id, episode_number) 
        values (kid_with_rem_ep.child_id, kid_with_rem_ep.episode_number);

        v_first_rem_loc_id := get_first_rem_loc_within_rem_ep(kid_with_rem_ep.child_id, kid_with_rem_ep.start_date); 
        
        v_initial_placement_quiz_id := null;

        select initial_placement_quiz_id into v_initial_placement_quiz_id
        from removal_locations
        where id = v_first_rem_loc_id;

        perform get_from_initial_placement_quiz(kid_with_rem_ep.child_id, 
                  kid_with_rem_ep.episode_number, v_initial_placement_quiz_id); 
        perform case_county_for_kids_like_my_kids(kid_with_rem_ep.child_id, 
                  kid_with_rem_ep.episode_number);
        
      end loop;
    end;
$$ LANGUAGE plpgsql;


