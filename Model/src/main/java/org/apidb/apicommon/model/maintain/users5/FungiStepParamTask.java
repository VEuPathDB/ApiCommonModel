package org.apidb.apicommon.model.maintain.users5;

import java.util.List;

import org.apache.ibatis.session.SqlSession;
import org.apache.log4j.Logger;
import org.apidb.apicommon.model.maintain.users5.mapper.FungiStepMapper;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * @author jerric
 * 
 *         The task migrate user baskets for fungi users. This task has to be executed after FungiUserTask.
 */
public class FungiStepParamTask implements MigrationTask {

  private static final Logger LOG = Logger.getLogger(FungiStepParamTask.class);

  private static final String[] LEFT_MAP = { "gene_result", "span_result", "sequence_result",
      "compound_result", "pathway_result", "group_answer", "sequence_answer", "htsIsolateList" };

  @Override
  public String getDisplay() {
    return "Fix step params for Fungi steps";
  }

  @Override
  public boolean isBatchEnabled() {
    return true;
  }

  @Override
  public void execute(SqlSession session) throws Exception {
    FungiStepMapper mapper = session.getMapper(FungiStepMapper.class);

    // update the answerParam values with left/right child step_ids
    List<StepInfo> steps = mapper.selectCombinedSteps();
    LOG.debug(steps.size() + " steps to be updated.");
    for (StepInfo step : steps) {
      fixStepParams(step);
      mapper.updateStepParams(step);
      // release memory
      step.setParams(null);
    }
  }

  private void fixStepParams(StepInfo step) throws JSONException {
    String leftChild = Integer.toString(step.getLeftChild());
    String rightChild = Integer.toString(step.getRightChild());

    // get params JSON
    JSONObject params = new JSONObject(step.getParams());

    String[] names = JSONObject.getNames(params);
    boolean leftFound = false, rightFound = false;
    for (String name : names) {
      if (name.startsWith("bq_left_op_")) {
        params.put(name, leftChild);
        leftFound = true;
      }
      else if (name.startsWith("bq_right_op_")) {
        params.put(name, rightChild);
        rightFound = true;
      }
    }
    params.remove("span_a)");
    params.remove("span_b)");
    if (!leftFound && !rightFound) {
      if (rightChild.equals("0")) { // only left child has value
        for (String name : LEFT_MAP) {
          if (params.has(name)) {
            params.put(name, leftChild);
            leftFound = true;
          }
        }
      }
      else { // both left and right child have values
        if (params.has("span_a")) {
          params.put("span_a", leftChild);
          leftFound = true;
        }
        if (params.has("span_b")) {
          params.put("span_b", rightChild);
          rightFound = true;
        }
      }
    }
    if (!leftFound && !rightFound) {
      LOG.error("Couldn't find step param to update in step: #" + step.getId());
    }
    else {
      // set the params back
      step.setParams(params.toString());
    }
  }

  @Override
  public boolean validate(SqlSession session) {
    // TODO - need to add validations later
    return true;
  }

}
