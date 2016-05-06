jenkin_credentials_id = '76b7646a-acaa-47eb-af35-815a9f0b6ae3'
chef_repo_git_url = env.CHEF_REPO_GIT_URL // 'https://github.com/ChefCookbooks/chef-repo.git'
git_oauth_token = env.GIT_OAUTH_TOKEN // 'f3fa123456abc0b123e90b6123456abcd123ada2'
git_api_url = env.GIT_API_URL // 'https://github.com/api/v3'

slack_channel = env.SLACK_CHANNEL // '#chef-pipelines'
slack_team = env.SLACK_TEAM // 'my_company'
slack_token = env.SLACK_TOKEN // 'ZJsABCszDEFGHtN3e1234Wju'

s3_bucket = env.S3_BUCKET // s3://my-company/chef-repo
chef_key_name = env.CHEF_KEY_NAME //'alexmanly.pem'

jenkins_url = 'http://0.0.0.0:8080'

values = env.JOB_NAME.split('/')
org = values[0]
cookbook_name = values[1]
git_branch = values[2].replaceAll('%2F', '/')

cb_version = null
git_url = null
git_commit_sha = null
git_pr_url = null
jenkins_job_url = null
chef_server_url = null

stage 'Verify'
node {
    if (org) {
        echo "Git organisation is: -->" + org + "<--"
    }

    if (git_branch) {
        echo "Git branch name is: -->" + git_branch + "<--"
    }

    if (cookbook_name) {
        echo "Cookbook name is: -->" + cookbook_name + "<--"
    }

    jenkins_job_url = jenkins_url + '/job/' + org +'/job/' + cookbook_name + '/branch/' + git_branch.replaceAll('/', '%252F')
    if (jenkins_job_url) {
        echo "Jenkins job URL is: -->" + jenkins_job_url + "<--"
    }

    git url: "${chef_repo_git_url}", branch: 'master', credentialsId: "${jenkin_credentials_id}"

    sh "/usr/local/bin/aws s3 cp ${s3_bucket}/knife.rb .chef/knife.rb"
    chef_server_url = get_chef_server('.chef/knife.rb')
    if (chef_server_url) {
        echo "Chef server URL is: -->" + chef_server_url + "<--"
    }
    sh "/usr/local/bin/aws s3 cp ${s3_bucket}/${chef_key_name} .chef/${chef_key_name}"

    sh "mkdir -p cookbooks/${cookbook_name}"
    dir("cookbooks/${cookbook_name}") {
        checkout scm
        git_commit_sha = get_git_commit()
        if (git_commit_sha) {
            echo "Git commit SHA is: -->" + git_commit_sha + "<--"
        }
        git_url = get_git_url()
        if (git_url) {
            echo "Git repository URL is: -->" + git_url + "<--"
        }

        cb_version = get_version('metadata.rb')
        if (cb_version) {
            echo "Cookbook version is: -->" + cb_version + "<--"
        }

        if (git_branch != 'master') {
            git_pr_url = createPR(git_branch)
            if (git_pr_url) {
                echo "Git pull request URL is: -->" + git_pr_url + "<--"
            }
            setPRStatus('pending', 'This cookbook is being tested in Jenkins.')
        }

        sh "knife cookbook test -o . -a"
        //sh "rubocop ."
        sh "foodcritic  . -f any"
        sh "chef exec rspec"
        //sh "kitchen test"

        if (git_branch != 'master') {
          setPRStatus('success', 'This cookbook is has passed all tests in Jenkins.')
        }
    }
}

if (git_branch != 'master') {
    stage 'Approval'
    node('master') {
        def pr_url = git_pr_url.replaceAll('/api/v3/repos' ,'')
        pr_url = pr_url.replaceAll('/pulls/', '/pull/')

        slackSend channel: slack_channel, color: 'good', failOnError: true, teamDomain: slack_team, token: slack_token, message: "Cookbook \'${cookbook_name}:${cb_version}\' has been modified and requires approval.\nThe pull request can be viewed in GitHub here: ${pr_url}.\nAfter you have reviewed the pull request, go into Jenkins and approve the pipeline to proceed: ${jenkins_job_url}"

        input 'Please review and comment on the pull request in GitHub: ' + pr_url + ', then click Proceed to approve this new feature.'

        mergePR(git_pr_url)
    }
}
if (git_branch == 'master') {
    stage 'Build'
    node('master') {
        sh "knife ssl fetch"
        sh "knife cookbook upload ${cookbook_name} --freeze"

        echo "Cookbook '${cookbook_name}:${cb_version}' has been uploaded to the Chef Server: ${chef_server_url}"
        slackSend channel: slack_channel, color: 'good', failOnError: true, teamDomain: slack_team, token: slack_token, message: "Cookbook '${cookbook_name}:${cb_version}' has been uploaded to the Chef Server: ${chef_server_url}"
    }

    stage 'Deploy: Dev'
    node('master') {
        deploy(false, 'DEV')
    }

    stage 'Deploy: Pre-Prod'
    node('master') {
       deploy(true, 'PREPROD')
    }

    stage 'Deploy: Prod'
    node('master') {
        deploy(true, 'PROD')
    }
}

def get_git_commit() {
    sh "git rev-parse HEAD > OUTPUT"
    return read_output("OUTPUT")
}

def get_git_url() {
    sh "git config --get remote.origin.url > OUTPUT"
    return read_output("OUTPUT")
}

def read_output(String file_name) {
    def val = readFile(file_name).trim()
    sh "rm ${file_name}"
    return val
}

def get_version(String file_name) {
    def metaversion = readFile(file_name) =~ "version[\\s]+'([0-9]+\\.[0-9]+\\.[0-9]+)'"
    metaversion ? metaversion[0][1].trim() : null
}

def get_chef_server(String file_name) {
    def chef_server_regex = readFile(file_name) =~ "chef_server_url[\\s]+[\"'](.+)[\"']"
    chef_server_regex ? chef_server_regex[0][1].trim() : null
}

def deploy(boolean approval, String environment){
    def env = environment
    def search_criteria = "(chef_environment:${env} AND (recipe:${cookbook_name}))"
    sh "knife search node '${search_criteria}' -a fqdn > OUTPUT"
    def nodes = read_output("OUTPUT")
    def node_comment = "There are 0 nodes affected by this change."
    if (nodes?.trim()) {
        node_comment = "Nodes affected by this change: ${nodes}"
    }
    echo node_comment

    if (approval) {
        slackSend channel: slack_channel, color: 'good', failOnError: true, teamDomain: slack_team, token: slack_token, message: "Cookbook ${cookbook_name}:${cb_version} is ready for deployment into ${env}. ${node_comment}.  Please approve deployment ${jenkins_job_url}."
        input "Approve deployment of cookbook ${cookbook_name}:${cb_version} to the ${env} environment?"
    } else {
        slackSend channel: slack_channel, color: 'good', failOnError: true, teamDomain: slack_team, token: slack_token, message: "Cookbook ${cookbook_name}:${cb_version} is ready for deployment into ${env}. ${node_comment}.  This environment does not require deployment approval ${jenkins_job_url}."
    }
    sh "knife spork promote ${env} ${cookbook_name} -v ${cb_version} -y"
    sh "knife spork environment check ${env}"
    sh "knife environment from file environments/${env}.json"
    echo "Cookbook '${cookbook_name}:${cb_version}' has been pinned to the environment ${env} in the Chef Server: ${chef_server_url}"
    sh "knife environment show ${env}"
    
    // Commit environment file into master
    // Need to set username and password
    //sh "git add environments/${env}.json && git commit -m \"Pinned cookbook \'${cookbook_name}\' to version ${cb_version}\" && git push origin master"

    sh "knife job start 'chef-client' --search '${search_criteria}'"
    //TODO script to check if deployment finished 
    
}

def createPR(String git_branch) {
    return executeCURL(true, 'curl -XPOST -H "Authorization: token ' + git_oauth_token + '" ${git_api_url}/repos/' + org +'/' + cookbook_name + '/pulls -d "{ \\\"title\\\": \\\"PR from Jenkins\\\", \\\"head\\\": \\\"' + git_branch + '\\\", \\\"base\\\": \\\"master\\\", \\\"body\\\": \\\"Pull request created by Jenkins job: ' + jenkins_job_url + '.\\\" }"')
}

def setPRStatus(String status, String desc) {
    return executeCURL(false, 'curl -XPOST -H "Authorization: token ' + git_oauth_token + '" ${git_api_url}/repos/' + org +'/' + cookbook_name + '/statuses/' + git_commit_sha + ' -d "{ \\\"state\\\": \\\"' + status + '\\\", \\\"target_url\\\": \\\"http://0.0.0.0:8080/job/' + org + '/job/' + cookbook_name + '/branch/' + git_branch + '\\\", \\\"description\\\": \\\"' + desc + '\\\", \\\"context\\\": \\\"Jenkins\\\" }"')
}

def mergePR(String pr_url) {
    def command = 'curl -XGET -H "Authorization: token ' + git_oauth_token + '" ' + pr_url + ' > CURL_RESPONSE'
    //echo('Executing cmd: ' + command)
    sh(command + ' > CURL_RESPONSE')
    def jsonString = read_output('CURL_RESPONSE')
    //echo('jsonString: -->' + jsonString + '<--')
    def jsonObject = new groovy.json.JsonSlurper().parseText(jsonString)
    def pr_merged = jsonObject.merged
    def pr_mergeable = jsonObject.mergeable
    def pr_merged_by = jsonObject.merged_by
    jsonObject = null
    //echo('set jsonObject as null')
    if (!pr_merged) {
        if (pr_mergeable) {
            echo('The PR: ' + pr_url + ' is in a mergable state and is about to be merge.')
            executeCURL(false, 'curl -XPUT -H "Authorization: token ' + git_oauth_token + '" ' + pr_url + '/merge -d "{ \\\"commit_title\\\": \\\"merge\\\", \\\"commit_message\\\": \\\"Merge after successful Jenkins build\\\", \\\"sha\\\": \\\"' + git_commit_sha + '\\\", \\\"squash\\\": true }"')
            echo('The PR: ' + pr_url + ' has been merged by Jenkins')
        } else {
            echo('The PR: ' + pr_url + ' is not in a mergeable state please check in GitHub')
        }
    } else {
        echo('The PR: ' + pr_url + ' has already been merged by ' + pr_merged_by)
    }
}

def executeCURL(boolean getUrl, String command) {
    //echo('Executing cmd: ' + command)
    sh(command + ' > CURL_RESPONSE')
    def jsonString = read_output('CURL_RESPONSE')
    //echo('jsonString: -->' + jsonString + '<--')
    def jsonObject = new groovy.json.JsonSlurper().parseText(jsonString)
    def pr_url = null
    if (getUrl) {
        pr_url = jsonObject.url
    //    echo('URL: -->' + pr_url + '<--')
    }
    jsonObject = null
    //echo('set jsonObject as null')
    return pr_url
}
