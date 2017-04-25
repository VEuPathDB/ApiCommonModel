package org.apidb.apicommon.model.maintain.users5;

public class StepInfo {

  private int id;
  private int leftChild;
  private int rightChild;
  private String params;

  /**
   * @return the id
   */
  public int getId() {
    return id;
  }

  /**
   * @param id
   *          the id to set
   */
  public void setId(int id) {
    this.id = id;
  }

  /**
   * @return the leftChild
   */
  public int getLeftChild() {
    return leftChild;
  }

  /**
   * @param leftChild
   *          the leftChild to set
   */
  public void setLeftChild(int leftChild) {
    this.leftChild = leftChild;
  }

  /**
   * @return the rightChild
   */
  public int getRightChild() {
    return rightChild;
  }

  /**
   * @param rightChild
   *          the rightChild to set
   */
  public void setRightChild(int rightChild) {
    this.rightChild = rightChild;
  }

  /**
   * @return the params
   */
  public String getParams() {
    return params;
  }

  /**
   * @param params
   *          the params to set
   */
  public void setParams(String params) {
    this.params = params;
  }

}
