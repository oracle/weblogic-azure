## GitHub Action: Check ARM VM Size Changes

### Overview
This GitHub Action runs on a schedule to check for changes in Azure ARM VM sizes and creates a pull request to update configurations if changes are detected.

### Schedule
- **Frequency:** Every 14 days (2 weeks)
- **Schedule Expression:** `0 0 */14 * *` (Runs at midnight (00:00) UTC)

The schedule event only happens in [azure-javaee/weblogic-azure](https://github.com/azure-javaee/weblogic-azure).

If you want to run the action in your repository, you have to trigger it from Web Browser.

### Environment Variables
- **azureCredentials:** Secret for Azure credentials
- **repoName:** Repository name set to "weblogic-azure"
- **userEmail:** Secret for user Email of GitHub acount to access GitHub repository
- **userName:** Secret for user name of GitHub account

### Jobs
#### check-vm-sizes
- **Runs on:** `ubuntu-latest`
- **Steps:**
  1. **Checkout repository:** Checks out the repository using `actions/checkout@v2`.
  
  2. **Azure Login:** Logs into Azure using `azure/login@v1`.
  
  3. **Check for VM size changes:**
     - Reads from `resources/azure-common.properties`.
     - Extracts and compares current VM sizes with the latest available.
     - Determines if there are changes and prepares data for output.

  4. **Create PR if changes detected:**
     - Conditionally creates a pull request if changes in ARM VM sizes are detected.
     - Updates the ARM VM sizes configuration in `resources/azure-common.properties`.
     - Commits changes to a new branch and pushes to origin.
     - Creates a pull request with a title and description based on detected changes.

### Run the action

You can use `.github/resource/azure-credential-setup-wls-vm.sh` to create GitHub Action Secret for the pipeline.

1. Fill in `.github/resource/credentials-params-wls-vm.yaml` with your values.

   | Variable Name | Value |
   |----------------|----------------------|
   | OTN_USERID | Oracle single sign-on userid. If you don't have one, sign up from [Create Your Oracle Account](https://profile.oracle.com/myprofile/account/create-account.jspx?nexturl=https%3A%2F%2Fsupport.oracle.com&pid=mos) |
   | OTN_PASSWORD | Password for Oracle single sign-on userid. |
   | WLS_PSW | Password for WebLogic Server. | 
   | USER_EMAIL | User Email of GitHub acount to access GitHub repository. |
   | USER_NAME | User name of GitHub account. |
   | GIT_TOKEN | GitHub token to access GitHub repository. <br /> Make sure the token have permissions: <br /> - Read and write of Pull requests. <br /> - Read and write of Contents. |

2. Set up secret

    Run `azure-credential-setup-wls-vm.sh` to set up secret.

    ```shell
    bash .github/resource/azure-credential-setup-wls-vm.sh
    ```

    Follow the output to set up secrets.

3. Trigger the workflow

   - Fork this repo from [oracle/weblogic-azure](https://github.com/azure-javaee/weblogic-azure).

   - Enable workflow in the fork. Select **Actions**, then follow the instructions to enable workflow.

   - Select **Actions** -> **Check ARM VM Size Changes** -> **Run workflow** to run the workflow.

