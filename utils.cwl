#!/usr/bin/env cwl-runner
#
# Throws invalid error which invalidates the workflow
# This workflow will return:
# 1. questions, downsampling folder, which will be used for the model
# 2. experimental conditions and proportions, which will be used for validation and scoring

cwlVersion: v1.0
class: ExpressionTool

inputs:
  - id: queue
    type: string

outputs:
  - id: question
    type: string
  - id: proportion
    type: string[]
  - id: condition
    type: string[]
  - id: input_dir
    type: string
  - id: file_prefix
    type: string
  - id: gs_synId
    type: string

requirements:
  - class: InlineJavascriptRequirement

expression: |

  ${
    // since cwl only support ES5
    // using 'let' will have warning
    // using big fat arrow will have waring
    var ds_folder = "/home/ec2-user/challenge-data/downsampled"
    if (inputs.queue == "9615023" || inputs.queue == "9614943") {
      // TODO: may change to dictionary when we add dataset2 and dataset3
      var ds_prop = ["20k", "50k"]; // tmp for dataset1
      var condition = ["c1", "c2", "c3", "c4"]; // tmp for dataset1
      var input_dir = `${ds_folder}/scRNAseq/dataset1` // tmp for dataset1
      var prefix = "dataset1" // tmp for dataset1
      var gs_synId = "syn27919058" // tmp for dataset1
      var question = "1"
      
    } else if (inputs.queue == "9615024" || inputs.queue == "9615021") {
      var ds_prop = ["0_01"]; // TBD
      var condition = ["c1", "c2"]; // TBD
      var input_dir = `${ds_folder}/scATACseq` // TBD
      var gs_synId = "syn123" // TBD
      var prefix = "peak2A" // TBD
      var question = "2A"

    } else if (inputs.queue == "9615025" || inputs.queue == "9615022") {
      var ds_prop = ["0_01"]; // TBD
      var condition = ["c1", "c2"]; // TBD
      var input_dir = `${ds_folder}/scATACseq` // TBD
      var gs_synId = "syn123" // TBD
      var prefix = "peak2B" // TBD
      var question = "2B"

    } else {
      throw 'invalid queue';
    }
    return {question: question, 
            proportion: ds_prop, 
            condition: condition,
            input_dir: input_dir,
            gs_synId: gs_synId, 
            file_prefix: prefix};
  }
