# plan stage ------------------------------------------------------------------
resource "aws_codebuild_project" "tf-plan" {
  name          = "tf-cicd-plan2"
  description   = "Plan stage for terraform"
  service_role  = aws_iam_role.tf-codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "hashicorp/terraform:latest"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential{
        credential = var.dockerhub_credentials
        credential_provider = "SECRETS_MANAGER"
    }
 }
 source {
     type   = "CODEPIPELINE"
     buildspec = file("buildspec/plan-buildspec.yml")
 }
}

# apply stage ------------------------------------------------------------------
resource "aws_codebuild_project" "tf-apply" {
  name          = "tf-cicd-apply"
  description   = "Apply stage for terraform"
  service_role  = aws_iam_role.tf-codebuild-role.arn

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    # image                       = "hashicorp/terraform:0.14.3"
    image                       = "hashicorp/terraform:latest"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "SERVICE_ROLE"
    registry_credential{
        credential = var.dockerhub_credentials
        credential_provider = "SECRETS_MANAGER"
    }
 }
 source {
     type   = "CODEPIPELINE"
     buildspec = file("buildspec/apply-buildspec.yml")
 }
}

# pipeline stage ------------------------------------------------------------------

resource "aws_codepipeline" "cicd_pipeline" {

    name = "tf-cicd"
    role_arn = aws_iam_role.tf-codepipeline-role.arn
    artifact_store {
        type="S3"
        location = aws_s3_bucket.codepipeline_artifacts.id
    }

    stage {
        name = "Source"
        action{
            name = "Source"
            category = "Source"
            owner = "AWS"
            # provider = "CodeStarSourceConnection"
            provider = "CodeCommit"
            version = "1"
            # output_artifacts = ["tf-code"]
            # output_artifacts = ["source_output"]
            output_artifacts = ["CodeWorkspace"]
            configuration = {
                # FullRepositoryId = "davoclock/aws-cicd-pipeline"
                FullRepositoryId = "prajwal-27/aws-cicd-pipeline"
                # BranchName   = "master"
                BranchName   = "feature/branch_3rd_may_23"
                ConnectionArn = var.codestar_connector_credentials
                OutputArtifactFormat = "CODE_ZIP"
                PollForSourceChanges = true #--
            }
        }
    }

    stage {
        name ="Plan"
        action{
            name = "Build"
            category = "Build"
            provider = "CodeBuild"
            version = "1"
            owner = "AWS"
            input_artifacts  = ["CodeWorkspace"]
            output_artifacts = ["TerraformPlanFile"]
            # input_artifacts = ["tf-code"]
            # input_artifacts = ["source_output"]
            # output_artifacts = ["build_output"] #

            configuration = {
            ProjectName          = "tf-cicd-plan"
            EnvironmentVariables = jsonencode([
            {
                name  = "PIPELINE_EXECUTION_ID"
                value = "#{codepipeline.PipelineExecutionId}" # The codepipeline reserved namespace
                type  = "PLAINTEXT"
            }
            ])
        }

        }
    }

    stage {
        name = "Manual-Approval"

        action {
        run_order = 1
        name             = "AWS-Admin-Approval"
        category         = "Approval"
        owner            = "AWS"
        provider         = "Manual"
        version          = "1"
        input_artifacts  = []
        output_artifacts = []

        configuration = {
            CustomData = "Please verify the terraform plan output on the Plan stage and only approve this step if you see expected changes!"
        }
        }
    }

    stage {
        name ="Deploy"
        action{
            name = "Deploy"
            category = "Build"
            provider = "CodeBuild"
            version = "1"
            owner = "AWS"
            input_artifacts  = ["CodeWorkspace", "TerraformPlanFile"]
            output_artifacts = []
            # input_artifacts = ["build_output"]
            # input_artifacts = ["tf-code"]
            configuration = {
            ProjectName          = "tf-cicd-apply"
            PrimarySource        = "CodeWorkspace"
            EnvironmentVariables = jsonencode([
            {
                name  = "PIPELINE_EXECUTION_ID"
                value = "#{codepipeline.PipelineExecutionId}"
                type  = "PLAINTEXT"
            }
            ])
        }
        }
    }
}



# ------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------
# ------------------------------------------------------------------------------------------------------------------
