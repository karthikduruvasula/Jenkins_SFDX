pipeline {
     agent { label 'devops-agent' }

    // --- 1. Dynamic Parameters ---
    // In Multibranch, this allows Manual Overrides, but defaults to 'auto' for Webhooks
    parameters {
        choice(
            name: 'TARGET_ENV', 
            choices: ['auto', 'dev', 'qa', 'uat', 'prod'], 
            description: 'Select "auto" for webhook triggers, or override manually.'
        )
    }

    environment {
        // --- CREDENTIALS ---
        PROD_CLIENT_ID = credentials('ad051466-3a4f-43c7-8553-13757ba739c8')
        JWT_KEY_FILE   = credentials('7e390c5b-1f9b-4c03-8355-a04e93aed514')
    }

    stages {
        // --- STAGE 1: Determine Environment & Checkout ---
        stage('Setup & Checkout') {
            steps {
                script {
                    // 1. Checkout Code
                    checkout scm
                    sh "git fetch origin main || true" // Fetch main for Delta comparison

                    // 2. Determine Environment Logic
                    def selectedEnv = params.TARGET_ENV ?: 'auto'
                    def branchName = env.BRANCH_NAME
                    
                    // Logic: If 'auto', pick env based on Branch Name
                    if (selectedEnv == 'auto') {
                        if (branchName.startsWith('feature/')) {
                            env.FINAL_ENV = 'qa' // Feature branches -> SIT/QA
                        } else if (branchName == 'main') {
                            env.FINAL_ENV = 'prod'
                        } else if (branchName.startsWith('release/')) {
                            env.FINAL_ENV = 'uat'
                        } else {
                            env.FINAL_ENV = 'dev' // Default fallback
                        }
                    } else {
                        env.FINAL_ENV = selectedEnv // Manual Override
                    }

                    // 3. Set Org Alias & Credentials based on Final Env
                    env.SF_ALIAS = "${env.FINAL_ENV}_org"
                    
                    // Define usernames map
                    if (env.FINAL_ENV == 'qa') {
                        env.SF_USERNAME = "kduruvasula-demo@salesforce.com.qa"
                        env.SF_URL = "https://test.salesforce.com"
                    } else if (env.FINAL_ENV == 'uat') {
                        env.SF_USERNAME = "kduruvasula-demo@salesforce.com.uat"
                        env.SF_URL = "https://test.salesforce.com"
                    } else if (env.FINAL_ENV == 'prod') {
                        env.SF_USERNAME = "kduruvasula-demo@salesforce.com"
                        env.SF_URL = "https://login.salesforce.com"
                        env.SF_ALIAS = "prod_org"
                    } else {
                        env.SF_USERNAME = "kduruvasula-demo@salesforce.com.dev1"
                        env.SF_URL = "https://test.salesforce.com"
                    }

                    echo "------------------------------------------------"
                    echo "Branch: ${branchName} | Target: ${env.FINAL_ENV}"
                    echo "------------------------------------------------"
                }
            }
        }

        // --- STAGE 2: Authenticate ---
        stage('Authenticate') {
            steps {
                script {
                    sh """
                        sf org login jwt \
                            --client-id "${env.PROD_CLIENT_ID}" \
                            --jwt-key-file "${env.JWT_KEY_FILE}" \
                            --username "${env.SF_USERNAME}" \
                            --instance-url "${env.SF_URL}" \
                            --alias "${env.SF_ALIAS}" \
                            --set-default
                    """
                }
            }
        }

        // --- STAGE 3: Generate Delta ---
        stage('Generate Delta') {
            steps {
                script {
                    echo "Cleaning previous delta artifacts..."  
                    sh "rm -rf changed-sources"

                    sh "mkdir -p changed-sources"
                    // Generate Delta based on diff against main
                    sh """
                        sf sgd:source:delta \
                            --to "HEAD" \
                            --from "origin/main" \
                            --output-dir "changed-sources" \
                            --generate-delta
                    """
                }
            }
        }

        // --- STAGE 4: Validate & Test (Apex Tests) ---
        stage('Validate & Apex Tests') {
            steps {
                script {
                    if (fileExists('changed-sources/package/package.xml')) {
                        echo "Validating and Running Local Tests on ${env.SF_ALIAS}..."
                        
                        // --dry-run: Don't save yet
                        // --test-level RunLocalTests: Runs all local tests in the org to ensure quality
                        sh """
                            sf project deploy start \
                                --dry-run \
                                --manifest "changed-sources/package/package.xml" \
                                --target-org "${env.SF_ALIAS}" \
                                --test-level RunLocalTests \
                                --wait 30
                        """
                    } else {
                        echo "No changes to validate."
                    }
                }
            }
        }

        // --- STAGE 5: Deploy Changes ---
        stage('Deploy Changes') {
            steps {
                script {
                    if (fileExists('changed-sources/package/package.xml')) {
                        echo "Deploying to ${env.SF_ALIAS}..."
                        
                        // Actual Deployment (No dry-run)
                        // Note: If you want to skip running tests again to save time, use --test-level NoTestRun 
                        // (only if you trust the validation step completely and are not in Prod)
                        sh """
                            sf project deploy start \
                                --manifest "changed-sources/package/package.xml" \
                                --target-org "${env.SF_ALIAS}" \
                                --ignore-conflicts \
                                --wait 30
                        """
                    } else {
                        echo "No changes to deploy."
                    }
                }
            }
        }
    }
}