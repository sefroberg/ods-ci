*** Settings ***
Documentation       Test suite testing ODS Metrics related to billing
Resource            ../../../../Resources/RHOSi.resource
Resource            ../../../../Resources/ODS.robot
Resource            ../../../../Resources/Common.robot
Resource            ../../../../Resources/Page/OCPDashboard/OCPDashboard.resource
Resource            ../../../../Resources/Page/OCPDashboard/Monitoring/Metrics.robot
Resource            ../../../../Resources/Page/ODH/JupyterHub/JupyterLabLauncher.robot
Resource            ../../../../Resources/Page/ODH/JupyterHub/JupyterHubSpawner.robot
Resource            ../../../../Resources/Page/OCPLogin/OCPLogin.resource
Resource            ../../../../Resources/OCP.resource
Library             JupyterLibrary
Library             SeleniumLibrary

Suite Setup         Billing Metrics Suite Setup
Suite Teardown      RHOSi Teardown


*** Variables ***
${METRIC_RHODS_CPU}                 cluster:usage:consumption:rhods:cpu:seconds:rate1h
${METRIC_RHODS_UNDEFINED}           cluster:usage:consumption:rhods:undefined:seconds:rate5m


*** Test Cases ***
Verify OpenShift Monitoring Results Are Correct When Running Undefined Queries
    [Documentation]     Verifies openshift monitoring results are correct when firing undefined queries
    [Tags]    Sanity
    ...       Tier1
    ...       ODS-173
    ...       Monitoring
    ...       AutomationBug
    Run OpenShift Metrics Query    ${METRIC_RHODS_UNDEFINED}   username=${OCP_ADMIN_USER.USERNAME}   password=${OCP_ADMIN_USER.PASSWORD}
    ...    auth_type=${OCP_ADMIN_USER.AUTH_TYPE}   retry_attempts=1
    Metrics.Verify Query Results Dont Contain Data
    [Teardown]    Close All Browsers

Test Billing Metric (Notebook Cpu Usage) On OpenShift Monitoring
    [Documentation]     Run notebook for 5 min and checks CPU usage is greater than zero
    [Tags]    Sanity
    ...       Tier1
    ...       ODS-175
    ...       Monitoring
    ...       AutomationBug
    Run Jupyter Notebook For 5 Minutes
    Verify Previus CPU Usage Is Greater Than Zero
    [Teardown]    CleanUp JupyterHub And Close All Browsers

Test Metric "Rhods_Total_Users" On Cluster Monitoring Prometheus
    [Documentation]     Verifies the openshift metrics and rhods prometheus showing same rhods_total_users values
    [Tags]    Sanity
    ...       ODS-634
    ...       Tier1
    ...       Monitoring
    Skip If RHODS Is Self-Managed
    ${value} =    Run OpenShift Metrics Query    query=rhods_total_users   username=${OCP_ADMIN_USER.USERNAME}   password=${OCP_ADMIN_USER.PASSWORD}
    ...    auth_type=${OCP_ADMIN_USER.AUTH_TYPE}
    ${value_from_promothues} =    Fire Query On RHODS Prometheus And Return Value    query=rhods_total_users
    Should Be Equal    ${value_from_promothues}    ${value}
    [Teardown]    Close All Browsers

Test Metric "Rhods_Aggregate_Availability" On Cluster Monitoring Prometheus
    [Documentation]     Verifies metric rhods_aggregate_availability exist in OpenShift > Observe > Metrics and
    ...   in RHODS Prometheus. Verify their value matches
    [Tags]    Smoke
    ...       ODS-637
    ...       Tier1
    ...       Monitoring
    Skip If RHODS Is Self-Managed

    ${value_openshift_observe} =    Run OpenShift Metrics Query
    ...    query=rhods_aggregate_availability   username=${OCP_ADMIN_USER.USERNAME}   password=${OCP_ADMIN_USER.PASSWORD}
    ...    auth_type=${OCP_ADMIN_USER.AUTH_TYPE}    retry_attempts=1    return_zero_if_result_empty=False

    SeleniumLibrary.Capture Page Screenshot

    Should Not Be Empty    ${value_openshift_observe}
    ...    msg=Metric rhods_aggregate_availability is empty in OpenShift>Observe>Metrics

    ${value_prometheus} =    Fire Query On RHODS Prometheus And Return Value    query=rhods_aggregate_availability
    Should Be Equal    ${value_prometheus}    ${value_openshift_observe}
    [Teardown]    SeleniumLibrary.Close All Browsers

Test Metric "Active_Users" On OpenShift Monitoring On Cluster Monitoring Prometheus
    [Documentation]    Test launchs notebook for N user and and checks Openshift Matrics showing N active users
    [Tags]    Sanity
    ...       ODS-1053
    ...       Tier1
    ...       Monitoring
    ...       AutomationBug
    ${active_users_before} =    Run OpenShift Metrics Query
    ...    username=${OCP_ADMIN_USER.USERNAME}    password=${OCP_ADMIN_USER.PASSWORD}
    ...    auth_type=${OCP_ADMIN_USER.AUTH_TYPE}   query=cluster:usage:consumption:rhods:active_users
    ...    retry_attempts=1    return_zero_if_result_empty=True

    @{list_of_usernames} =    Create List    ${TEST_USER_3.USERNAME}    ${TEST_USER_4.USERNAME}
    ${expected_increase_active_users} =    Get Length   ${list_of_usernames}

    Log In N Users To JupyterLab And Launch A Notebook For Each Of Them
    ...    list_of_usernames=${list_of_usernames}

    Sleep    60s    reason=Wait until metrics are available

    ${active_users_after} =    Run OpenShift Metrics Query
    ...    username=${OCP_ADMIN_USER.USERNAME}    password=${OCP_ADMIN_USER.PASSWORD}
    ...    auth_type=${OCP_ADMIN_USER.AUTH_TYPE}   query=cluster:usage:consumption:rhods:active_users
    ...    retry_attempts=1    return_zero_if_result_empty=True
    ${increase_active_users} =    Evaluate    ${active_users_after}-${active_users_before}

    Should Be Equal As Integers    ${expected_increase_active_users}    ${increase_active_users}
    ...    msg=Unexpected active_users value

    [Teardown]    CleanUp JupyterHub For N Users    list_of_usernames=${list_of_usernames}

Test Metric "Active Notebook Pod Time" On OpenShift Monitoring - Cluster Monitoring Prometheus
    [Documentation]    Test launchs notebook for N user and and checks Openshift Matrics showing number of running pods
    [Tags]    Sanity
    ...       ODS-1055
    ...       Tier1
    ...       Monitoring
    ...       AutomationBug
    @{list_of_usernames} =    Create List    ${TEST_USER_3.USERNAME}    ${TEST_USER_4.USERNAME}
    Log In N Users To JupyterLab And Launch A Notebook For Each Of Them
    ...    list_of_usernames=${list_of_usernames}
    Sleep    60s    reason=Wait until metrics are available
    ${value} =    Run OpenShift Metrics Query    query=cluster:usage:consumption:rhods:pod:up   username=${OCP_ADMIN_USER.USERNAME}    password=${OCP_ADMIN_USER.PASSWORD}
    ...    auth_type=${OCP_ADMIN_USER.AUTH_TYPE}
    Should Not Be Empty    ${value}    msg=Metrics does not contains value for pod:up query
    [Teardown]    CleanUp JupyterHub For N Users    list_of_usernames=${list_of_usernames}


*** Keywords ***
Billing Metrics Suite Setup
    Set Library Search Order  SeleniumLibrary
    RHOSi Setup

CleanUp JupyterHub And Close All Browsers
    CleanUp JupyterHub
    Close All Browsers

Test Setup For Matrics Web Test
    [Documentation]     Opens openshift console metrics for metrics test
    Set Library Search Order    SeleniumLibrary
    Open OCP Console
    Login To OCP
    Wait Until OpenShift Console Is Loaded
    Click Button    Observe
    Click Link    Metrics
    Wait Until Element Is Visible    xpath://textarea[@class="pf-v6-c-form-control query-browser__query-input"]

Test Teardown For Matrics Web Test
    [Documentation]     Closes all browsers
    Close All Browsers

Run Query On Metrics And Return Value
    [Documentation]    Fires query in metrics through web browser and returns value
    [Arguments]    ${query}    ${count_of_columns}    # count of columns + 1 like name,values example: ${count_of_columns}=3
    Input Text    xpath://textarea[@class="pf-v6-c-form-control query-browser__query-input"]    ${query}
    Click Button    Run queries
    Wait Until Element is Visible    xpath://table[@class="pf-v6-c-table pf-m-compact"]    timeout=15seconds
    @{data} =    Get WebElements    //table[@class="pf-v6-c-table pf-m-compact"] //tbody/tr/td[${count_of_columns}]
    RETURN    ${data[0].text}

Fire Query On RHODS Prometheus And Return Value
    [Documentation]    Fires query in Prometheus through cli and returns value
    [Arguments]    ${query}
    ${expression} =    Set Variable    ${query}&step=1    #step = 1 beacuase it will return value of current second
    ${query_result} =    Prometheus.Run Query    ${RHODS_PROMETHEUS_URL}    ${RHODS_PROMETHEUS_TOKEN}    ${expression}
    RETURN    ${query_result.json()["data"]["result"][0]["value"][-1]}

Skip Test If Previous CPU Usage Is Not Zero
    [Documentation]     Skips test if CPU usage is not zero
    ${metrics_value} =    Run OpenShift Metrics Query    ${METRIC_RHODS_CPU}    username=${OCP_ADMIN_USER.USERNAME}
    ...     password=${OCP_ADMIN_USER.PASSWORD}   auth_type=${OCP_ADMIN_USER.AUTH_TYPE}
    ${metrics_query_results_contain_data} =    Run Keyword And Return Status    Metrics.Verify Query Results Contain Data
    IF    ${metrics_query_results_contain_data}
        Log To Console    Current CPU usage: ${metrics_value}
        Skip if
        ...    ${metrics_value} > 0
        ...    The previos CPU usage is not zero. Current CPU usage: ${metrics_value}. Skiping test
    END

Verify Previus CPU Usage Is Greater Than Zero
    [Documentation]     Verifies the cpu usage is greater than zero
    ${metrics_value} =    Run OpenShift Metrics Query    ${METRIC_RHODS_CPU}    username=${OCP_ADMIN_USER.USERNAME}
    ...     password=${OCP_ADMIN_USER.PASSWORD}   auth_type=${OCP_ADMIN_USER.AUTH_TYPE}
    Metrics.Verify Query Results Contain Data
    Capture Page Screenshot
    Should Be True    ${metrics_value} > 0

## TODO: Add this keyword with the other JupyterHub stuff
Run Jupyter Notebook For 5 Minutes
    [Documentation]     Opens jupyter notebook and run for 5 min
    Open Browser    ${ODH_DASHBOARD_URL}    browser=${BROWSER.NAME}    options=${BROWSER.OPTIONS}
    Login To RHODS Dashboard    ${TEST_USER.USERNAME}    ${TEST_USER.PASSWORD}    ${TEST_USER.AUTH_TYPE}
    Wait For RHODS Dashboard To Load
    Iterative Image Test
    ...    science-notebook
    ...    https://github.com/lugi0/minimal-nb-image-test
    ...    minimal-nb-image-test/minimal-nb.ipynb

##TODO: This is a copy of "Iterative Image Test" keyword from image-iteration.robob. We have to refactor the code not to duplicate this method
Iterative Image Test
    [Documentation]     Launch the jupyterhub and clone from ${REPO_URL},clean jupyterlab after completing
    [Arguments]    ${image}    ${REPO_URL}    ${NOTEBOOK_TO_RUN}
    Launch Jupyter From RHODS Dashboard Link
    Login To Jupyterhub    ${TEST_USER.USERNAME}    ${TEST_USER.PASSWORD}    ${TEST_USER.AUTH_TYPE}
    Page Should Not Contain    403 : Forbidden
    Verify Service Account Authorization Not Required
    Fix Spawner Status
    Spawn Notebook With Arguments    image=${image}
    Run Cell And Check Output    print("Hello World!")    Hello World!
    Capture Page Screenshot
    JupyterLab Code Cell Error Output Should Not Be Visible
    #This ensures all workloads are run even if one (or more) fails
    Run Keyword And Warn On Failure    Clone Git Repository And Run    ${REPO_URL}    ${NOTEBOOK_TO_RUN}
    Clean Up Server
    Stop JupyterLab Notebook Server
    Go To    ${ODH_DASHBOARD_URL}
    Sleep    10

CleanUp JupyterHub
    [Documentation]     Cleans JupyterHub
    Open Browser    ${ODH_DASHBOARD_URL}    browser=${BROWSER.NAME}    options=${BROWSER.OPTIONS}
    Login To RHODS Dashboard    ${TEST_USER.USERNAME}    ${TEST_USER.PASSWORD}    ${TEST_USER.AUTH_TYPE}
    Wait For RHODS Dashboard To Load
    Launch Jupyter From RHODS Dashboard Link
    Login To Jupyterhub    ${TEST_USER.USERNAME}    ${TEST_USER.PASSWORD}    ${TEST_USER.AUTH_TYPE}
    Page Should Not Contain    403 : Forbidden
    Verify Service Account Authorization Not Required
    # Additional check on running server
    ${control_panel_visible} =  Control Panel Is Visible
    IF  ${control_panel_visible}==True
        Handle Control Panel
    END
    Common.End Web Test

