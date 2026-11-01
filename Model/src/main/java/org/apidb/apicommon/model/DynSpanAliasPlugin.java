package org.apidb.apicommon.model;

import org.gusdb.wdk.model.record.alias.QueryBasedPrimaryKeyAliasPlugin;

public class DynSpanAliasPlugin extends QueryBasedPrimaryKeyAliasPlugin {

  @Override
  protected String getRecordClassFullName() {
    return "DynSpanRecordClasses.DynSpanRecordClass";
  }

  @Override
  protected String getQueryFullName() {
    return "DynSpanAttributes.Bfmv";
  }

}
