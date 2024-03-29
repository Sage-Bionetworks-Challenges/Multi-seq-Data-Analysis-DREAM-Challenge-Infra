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
# try to avoid using funcs above

cwlVersion: v1.0
class: ExpressionTool

inputs:
  - id: queue
    type: string
  - id: phase
    type: string

outputs:
  - id: question
    type: string
  - id: input_dir
    type: string
  - id: gs_synId
    type: string
  - id: submission_phase
    type: string

requirements:
  - class: InlineJavascriptRequirement

expression: |
  ${
    if (inputs.queue == "9615023" || inputs.queue == "9614943" || inputs.queue == "9615324") {
      // sc1
      var gs_synId = "syn34612394"
      var question = "1"

      if (inputs.phase == "public") {
        var input_dir = "/home/ec2-user/challenge-data/downsampled/scrna-subset"
      } else {
        var input_dir = "/home/ec2-user/challenge-data/downsampled/scrna"
      }
      
    } else if (inputs.queue == "9615024" || inputs.queue == "9615021" || inputs.queue == "9615302") {
      // sc2
      var gs_synId = "syn35294386"
      var question = "2"

      if (inputs.phase == "public") {
        var input_dir = "/home/ec2-user/challenge-data/downsampled/scatac-subset"
      } else {
        var input_dir = "/home/ec2-user/challenge-data/downsampled/scatac"
      }

    } else {
      throw 'invalid queue';
    }

    return {
      question: question, 
      input_dir: input_dir,
      gs_synId: gs_synId,
      submission_phase: inputs.phase
    };
  }
