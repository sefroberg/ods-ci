*** Settings ***
Documentation     135 - RHODS_OPERATOR_LOGS_VERIFICATION
...               Verify that rhods operator log is clean and doesn't contain any error regarding resource kind
...
...               = Variables =
...               | Namespace                | Required |        RHODS Namespace/Project for RHODS operator POD |
...               | REGEX_PATTERN            | Required |        Regular Expression Pattern to match the erro msg in capture log|

Resource          ../../../../../Resources/RHOSi.resource

Library           Collections
Library           OpenShiftLibrary
Library           OperatingSystem
Library           String

Suite Setup       RHOSi Setup
Suite Teardown    RHOSi Teardown


*** Variables ***
${regex_pattern}       level":"([Ee]rror).*|([Ff]ailed) to list .*


*** Test Cases ***
Verify RHODS Operator Logs After Restart
   [Tags]  Sanity
   ...     ODS-1007
   ...     Operator
   Restart RHODS Operator Pod
   #Get the POD name
   ${data}       Run Keyword   Oc Get   kind=Pod     namespace=${OPERATOR_NAMESPACE}   label_selector=${OPERATOR_LABEL_SELECTOR}
   #Capture the logs based on containers
   ${rc}    ${val}    Run And Return Rc And Output   oc logs --tail=-1 ${data[0]['metadata']['name']} -n ${OPERATOR_NAMESPACE} -c ${OPERATOR_POD_CONTAINER_NAME}
   Run Keyword And Continue On Failure    Should Be Equal As Integers    ${rc}    0    oc command didn't end successfully
   #To check if command has been successfully executed and the logs have been captured
   IF    len($val)==${0}     FAIL   Either OC command has not been executed successfully or Logs are not present
   #Filter the error msg from the log captured
   ${match_list} 	 Get Regexp Matches   ${val}     ${regex_pattern}
   #Remove if any duplicate entry are present
   ${entry_msg}      Remove Duplicates      ${match_list}
   ${length}         Get Length   ${entry_msg}
   #Verify if captured logs has any error entry if yes fail the TC
   IF   ${length} != ${0}    FAIL    There are some error entry present in opeartor logs '${entry_msg}'
   ...       ELSE   Log   Operator log looks clean


*** Keywords ***
Restart RHODS Operator Pod
    [Documentation]    Restart the operator Pod by deleting it and waiting for a new one to be Ready
    Oc Delete    kind=Pod     namespace=${OPERATOR_NAMESPACE}    label_selector=${OPERATOR_LABEL_SELECTOR}
    Wait For Pods Status    namespace=${OPERATOR_NAMESPACE}  label_selector=${OPERATOR_LABEL_SELECTOR}  timeout=120
