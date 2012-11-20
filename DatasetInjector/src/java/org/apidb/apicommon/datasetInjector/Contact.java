package org.apidb.apicommon.datasetInjector;

public class Contact {
  private String name;
  private boolean isPrimary;
  private String email;
  private String institution;
  private String address;
  private String city;
  private String state;
  private String country;
  private String zip;


  public void setName(String name) {
    this.name  = name;
  }
  
  public void setIsPrimary(boolean isPrimary) {
    this.isPrimary = isPrimary;
  }
  
  public void setEmail(String email) {
    this.email  = email;
  }
  
  public void setInstitution(String institution) {
    this.institution  = institution;
  }
  
  public void setAddress(String address) {
    this.address  = address;
  }
  
  public void setCity(String city) {
    this.city  = city;
  }
  
  public void setState(String state) {
    this.state  = state;
  }
  
  public void setCountry(String country) {
    this.country  = country;
  }
  
  public void setZip(String zip) {
    this.zip  = zip;
  }
  
  public String getName() {
    return name;
  }
  
  public boolean getIsPrimary() {
    return isPrimary;
  }
  
  public String getEmail() {
    return email;
  }
  
  public String getInstitution() {
    return institution;
  }
  
  public String getAddress() {
    return address;
  }
  
  public String getCity() {
    return city;
  }
  
  public String getState() {
    return state;
  }
  
  public String getCountry() {
    return country;
  }
  
  public String getZip() {
    return zip;
  }
  
  
}
