#!/usr/bin/env cwl-runner
#
# Throws invalid error which invalidates the workflow
# This workflow will return:
# 1. questions, downsampling folder, which will be used for the model
# 2. experimental conditions and proportions, which will be used for validation and scoring
# since cwl only support ES5, using below will have warnings:
# 1. 'let'
# 2. big fat arrow
# 3. template literal syntax
# try to avoid using these above

cwlVersion: v1.0
class: ExpressionTool

inputs:
  - id: queue
    type: string

outputs:
  - id: question
    type: string
  - id: input_dir
    type: string
  - id: gs_synId
    type: string

requirements:
  - class: InlineJavascriptRequirement

expression: |

  ${
    var ds_folder = "/home/ec2-user/challenge-data/downsampled"
    if (inputs.queue == "9615023" || inputs.queue == "9614943") {
      var input_dir = "/home/ec2-user/challenge-data/downsampled/scRNAseq"
      var gs_synId = "syn28543032"
      var question = "1"
      
    } else if (inputs.queue == "9615024" || inputs.queue == "9615021") {
      var input_dir = "/home/ec2-user/challenge-data/downsampled/scATACseq/dataset1"
      var gs_synId = "syn123" // TBD
      var question = "2A"

    } else if (inputs.queue == "9615025" || inputs.queue == "9615022") {
      var input_dir = "/home/ec2-user/challenge-data/downsampled/scATACseq/dataset2"
      var gs_synId = "syn123" // TBD
      var question = "2B"
    } else {
      throw 'invalid queue';
    }
    return {question: question, 
            input_dir: input_dir,
            gs_synId: gs_synId
            };
  }
