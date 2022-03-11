#!/usr/bin/env cwl-runner
#
# Throws invalid error which invalidates the workflow
# Based on the question, return expected all groudtruth and prediction filenames,
# which will be used for validation and scoring

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
  - id: file_prefix
    type: string

requirements:
  - class: InlineJavascriptRequirement

expression: |

  ${
    // since cwl only support ES5
    // using 'let' will have warning
    // using big fat arrow will have waring
    // function get_gs_name(condition, prefix="") {
    //   const out = [];
    //   for (const c of condition) {
    //     out.push(`${prefix}_${c}_gs.csv`);
    //   };
    //   return out;
    // };
    // function get_pred_name(condition, proportion, prefix="") {
    //   const out = [];
    //   for (const p of proportion) {
    //     for (const c of condition) {
    //       out.push(`${prefix}_${c}_${p}_imputed.csv`);
    //     }
    //   }
    //   return out;
    // };

    if (inputs.queue == "9614943") {
      var ds_prop = ["0_125"]; // tmp
      var condition = ["c1", "c2"]; // tmp
      var prefix = "dataset1"
      var question = "1A"
      
    } else if (inputs.queue == "9615021") {
      var ds_prop = ["0_125"]; // tmp
      var condition = ["c1", "c2"]; // tmp
      var question = "1B"
      var prefix = "peak"
    } else {
      throw 'invalid queue';
    }
    return {question: question, 
            proportion: ds_prop, 
            condition: condition, 
            file_prefix: prefix};
  }
