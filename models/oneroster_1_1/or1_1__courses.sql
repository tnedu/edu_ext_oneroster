{{
  config(
    alias='courses'
    )
}}

{%- set orgtype = 'edorg' -%}
{% if var('oneroster:use_course_departments', false) %}
    {% set orgtype = 'dept' %}
{%- endif -%}
with stg_courses as (
    select * from {{ ref('stg_ef3__courses') }}
    where school_year = {{ var('oneroster:active_school_year') }}
),
subjects as (
    select course.k_course, 
        sort_array(collect_list(course.academic_subject)) as subject_codes_array,
        transform(
            sort_array(
                collect_list(
                    struct(course.academic_subject as code, desc.short_description as description)
                )
            ),
            x -> x.description
        ) as subjects_array
    from stg_courses course
    join {{ ref('stg_ef3__descriptors') }} desc
        on desc.code_value = course.academic_subject
        and desc.school_year = course.school_year
        and desc.tenant_code = course.tenant_code
        and desc.descriptor_name = 'academic_subject_descriptors'
    group by course.k_course
),
-- want courses defined by district, so grab this from offerings and reduce down
course_leas as (
    select distinct k_course, 
        cast(lea_id as int) as lea_id
    from {{ ref('stg_ef3__course_offerings') }} as co 
    join {{ ref('stg_ef3__schools') }} as s 
        on co.k_school = s.k_school
    where school_year = {{ var('oneroster:active_school_year') }}

{% if var('oneroster:use_course_departments', false) %}
),
clean_up_depts as (
    select 
        tenant_code,
        k_course,
        department_name
    from {{ ref('or1_1__department_helper') }}
{%- endif -%}
)
select 
    {{ gen_sourced_id('course') }} as `sourcedId`,
    null::string as `status`,
    null::date as `dateLastModified`, 
    {{ gen_sourced_id('school_year') }} as `schoolYearSourcedId`, 
    course_title as `title`, 
    course_code  as `courseCode`, 
    null::string as `grades`,
    {{ gen_sourced_id(orgtype) }} as `orgSourcedId`,
    -- required to be SCED codes, not generally available
    subjects.subjects_array as `subjects`,
    subjects.subject_codes_array as `subjectCodes`,
    {{ gen_natural_key('course') }} as `metadata.edu.natural_key`,
    crs.tenant_code
from stg_courses crs
left outer join subjects subjects
    on crs.k_course = subjects.k_course
join course_leas 
    on crs.k_course = course_leas.k_course
{% if var('oneroster:use_course_departments', false) %}
join clean_up_depts
    on crs.k_course = clean_up_depts.k_course
{% endif %}
