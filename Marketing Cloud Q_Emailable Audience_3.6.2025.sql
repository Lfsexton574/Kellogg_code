With deg As (
Select id_number
     , record_status_code As degree_record_status
     , degrees_concat
     , first_ksm_year
From rpt_pbh634.v_entity_ksm_degrees
Where (not program like '%UNK%'
And not program like '%NONGRD%')
)
,

KSM_Students As (
Select aff.id_number
     , aff.affil_code
     , aff.affil_status_code
     , aff.affil_level_code
     , aff.record_type_code
     , TMS_AFFILIATION_LEVEL.short_desc as aff_status_desc
     , TMS_AFFIL_STATUS.short_desc as status
     , Listagg (TMS_AFFIL_CODE.short_desc, ';  ') Within Group (Order By TMS_AFFIL_CODE.short_desc) as School
From affiliation aff
Left Join TMS_AFFIL_CODE on TMS_AFFIL_CODE.affil_code = aff.affil_code
Left Join TMS_AFFILIATION_LEVEL on TMS_AFFILIATION_LEVEL.affil_level_code = aff.affil_level_code
Left Join TMS_AFFIL_STATUS on TMS_AFFIL_STATUS.affil_status_code = aff.affil_status_code
Where aff.affil_level_code = 'AM'
And aff.affil_status_code = 'E'
And aff.affil_code = 'KM'
Group By aff.id_number
       , aff.affil_code
       , aff.affil_status_code
       , aff.affil_level_code
       , aff.record_type_code
       , TMS_AFFILIATION_LEVEL.short_desc
       , TMS_AFFIL_STATUS.short_desc
)
,

deg_or_stu As
(Select id_number
From deg
Union
Select id_number
From KSM_Students
)
,

facstaff As ( -- Based on NU_RPT_PKG_SCHOOL_TRANSACTION
Select Distinct af.id_number
              , tms_affil.short_desc As KSM_Faculty_or_Staff
From Affiliation af
Inner Join tms_affiliation_level tms_affil
      On af.affil_level_code = tms_affil.affil_level_code
Where af.affil_level_code In ('ES', 'EF') -- Staff, Faculty
And af.affil_status_code = 'C'
And af.affil_code = 'KM'
)
,

giv As
(Select id_number
     , NGC_LIFETIME_FULL_REC
     , Case When NGC_LIFETIME_FULL_REC >= '0' Then 'Y' Else '' End As Donor
From rpt_pbh634.v_ksm_giving_summary
Where NGC_LIFETIME_FULL_REC > '0'
)
,

rel As (
Select
     --, e.pref_mail_name
     --, e.institutional_suffix
       r.relation_id_number
     , LISTAGG(er.pref_mail_name, ',') WITHIN GROUP(ORDER BY r.relation_id_number) As Relation_Pref_Name
     , LISTAGG(er.institutional_suffix, ',') WITHIN GROUP(ORDER BY r.relation_id_number) As Relation_Inst_Suffix
     , LISTAGG(tmsr.short_desc, ',') WITHIN GROUP(ORDER BY r.relation_id_number) As Relationship
     , LISTAGG(r.id_number, ',') WITHIN GROUP(ORDER BY r.relation_id_number) As Alum_or_Stu_Rel_ID
     , LISTAGG(e.pref_mail_name, ',') WITHIN GROUP(ORDER BY r.relation_id_number) As Alum_or_Stu_Rel_Name
     , LISTAGG(e.institutional_suffix, ',') WITHIN GROUP(ORDER BY r.relation_id_number) As Alum_or_Stu_Rel_Inst_Suffix
From relationship r
Inner join entity e -- deg_or_stu
      On r.id_number = e.id_number
Inner join deg_or_stu ds
      On r.id_number = ds.id_number
Inner join entity er
      On r.relation_id_number = er.id_number
Inner Join tms_relationships tmsr
      On r.relation_type_code = tmsr.relation_type_code
Where r.relation_status_code = 'A'
And r.relation_type_code In ('DP', 'GG', 'GP', 'GU', 'PC', 'PL', 'PN', 'PP', 'PS')
And r.relation_id_number Not Like ' '
Group By r.relation_id_number
)
,

sps As (
Select es.id_number
     , deg.degrees_concat
     , es.spouse_id_number
     , Case When es.spouse_id_number <> ' ' Then 'Spouse of alum' Else '' End as Spouse_of_Alum
From entity es
Inner Join rpt_pbh634.v_entity_ksm_degrees deg
      On deg.id_number = es.id_number
Where es.spouse_id_number Not Like ' '
)
,

bc As (
Select comm.id_number
     , LISTAGG(comm.committee_code, ',') WITHIN GROUP(ORDER BY comm.id_number) As Committee_code
     , LISTAGG(tmst.short_desc, ',') WITHIN GROUP(ORDER BY comm.id_number) As Committee
     , LISTAGG(comm.committee_status_code, ',') WITHIN GROUP(ORDER BY comm.id_number) As Committee_Status
     , LISTAGG(tmscr.short_desc, ',') WITHIN GROUP(ORDER BY comm.id_number) As Comm_Role
--     , comm.xcomment
From committee comm
Inner Join tms_committee_role tmscr
      On comm.committee_role_code = tmscr.committee_role_code
Inner Join tms_committee_table tmst
      On comm.committee_code = tmst.committee_code
Where comm.committee_code In ('KPH', 'KFN', 'KAMP', 'U', 'KIC', 'KACNA', 'KPETC',
'HAK', 'KEBA', 'KWLC', 'APEAC', 'KREAC', 'MBAAC', 'KTC', 'KCGN', 'KCDO',
'KAYAB')
And committee_status_code = 'C'
And tmscr.short_desc <> 'Our NU Follower'
Group By comm.id_number
)
,

unions As (
Select id_number
From deg_or_stu
Union
Select id_number
From facstaff
Union
Select id_number
From giv
Union
Select relation_id_number
From rel
Union
Select spouse_id_number
From sps
Union
Select id_number
From bc
)
,

pref_email As (
Select em.id_number
     , em.email_address
     , em.preferred_ind
--     , shc.NO_EMAIL_IND
--     , shc.No_contact
From Email em
--Left Join rpt_pbh634.v_entity_special_handling SHC
--     on em.id_number = shc.id_number
Where em.email_status_code = 'A'
And em.preferred_ind = 'Y'
--And shc.NO_EMAIL_IND is NULL
--And shc.No_contact is NULL
)

Select un.id_number
     , eu.first_name
     , eu.last_name
     , eu.pref_mail_name
     , em.preferred_ind As Pref_Email_Ind
     , em.email_address
     , shc.NO_EMAIL_IND
     , shc.NO_CONTACT
     , shc.NO_EMAIL_SOL_IND
     , deg.degrees_concat
     , ksms.aff_status_desc
     , ksms.status
     , ksms.school
     , fos.KSM_Faculty_or_Staff
     , giv.Donor
     , rel.Alum_or_Stu_Rel_ID
     , rel.Alum_or_Stu_Rel_Name
     , rel.Alum_or_Stu_Rel_Inst_Suffix
     , rel.relationship
     , sps.Spouse_of_Alum
     , bc.committee
     , bc.Comm_Role
From unions un
Inner Join entity eu
     On un.id_number = eu.id_number
Left Join deg
     On un.id_number = deg.id_number
Left Join KSM_Students ksms
     On un.id_number = ksms.id_number
Left Join facstaff fos
     On un.id_number = fos.id_number
Left Join giv
     On un.id_number = giv.id_number
Left Join rel
     On un.id_number = rel.relation_id_number
Left Join sps
     On un.id_number = sps.spouse_id_number
Left Join bc
     On un.id_number = bc.id_number
Left Join pref_email em
     On un.id_number = em.id_number
Left Join rpt_pbh634.v_entity_special_handling SHC
     On un.id_number = shc.id_number
Where eu.record_status_code In ('A', 'L', 'C')
