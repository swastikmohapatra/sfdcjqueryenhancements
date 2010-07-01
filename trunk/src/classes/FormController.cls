//See bottom for copyright notice

public class FormController extends EnhancedComponentController {

    public Form__c form 							{ get; set; }
    public List<Form_Field__c> fields 				{ get; set; }
    public String testString 						{ get; set; }  
    public String formName 							{ get; set; }  
    public String UpdateFieldName 	 				{ get; set; }  

    public List<FieldWrapper> fieldsWithVal 		{ get; set; }
    public List<FieldWrapper> allFields 			{ get; set; }
    public List<FieldWrapper> fieldsWithAutoComplete{ get; set; }
    public List<FieldWrapper> fieldsWithShowRules 	{ get; set; }  
    public List<FieldWrapper> fieldsWithGroups 		{ get; set; }
    public List<FieldWrapper> fieldsWithDatePicker 	{ get; set; }
    public List<FieldWrapper> fieldsWithMultiSelect { get; set; }

    //Map that holds all the object names and tokens in your org
    Map<String, Schema.SObjectType> gd;
    public List<SObjectType> tokens = new List<SObjectType>();
    public SObject sobjectInstance 					{ get; set; } 
    public Boolean editMode 						{ get; set; }
    public PageControllerBase pageController   		{ get; set; }    
    public Boolean hasRequired						{ get; set; }    
        
    private static String DEFAULT_THEME = 'cupertino';
    
    public void getInit() {
  
		System.debug('FORMNAME1:' +formName);
        //get the url parameter indication the web form Id
       if (formName == null || formName == '' )
       		formName = System.currentPageReference().getParameters().get('name');
		System.debug('FORMNAME2:' +formName);

        //if(formId == null) {
        //    ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'This page required a Web Form id url parameter.'));
        //    return;
        //}
        
        if(formName == null) {
                        
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'You cannot access this page without a form name.'));
            return;  
        }
        try {

	        form = [select Id, Name, Object_Name__c, Object_Label__c, Return_URL__c, Description__c, Title__c, Background_Color__c, Style__c, Save_Button_Text__c, Text_Color__c, Default_Record__c from Form__c where name = :formname];        

        }
        catch(QueryException qe)	{
        	
			 ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'There is no form with this name.'));
			 return;      	
			 
        }    
        
        String mode = System.currentPageReference().getParameters().get('mode');
        
        if(mode == 'edit')
            editMode = true;
        else
            editMode = false;
            
        fields = [Select f.Name, f.Id, f.Type__c, f.Label__c, f.Order__c,  f.PicklistEntries__c, f.Width__c, 
                    f.Required__c, f.Hidden__c, f.Tooltip__c,
                    f.Requires_Verification__c, Object_Name__c, Group__c, Max_Length__c, Update_On__c
                    from Form_Field__c f where f.Form__c = :form.id order by f.Order__c];
                    
        fieldsWithVal = new List<FieldWrapper>();  
        allFields = new List<FieldWrapper>();  
        fieldsWithShowRules = new List<FieldWrapper>();
        fieldsWithGroups = new List<FieldWrapper>();
		hasRequired = false;
		
        for(Form_Field__c f : fields)
        {
        	 f.width__c = 200;
             FieldWrapper fwv = new FieldWrapper(f);
             if(fwv.hasValRules)
                fieldsWithVal.add(fwv);
             if(fwv.getHasShowRules())
             	fieldsWithShowRules.add(fwv);   
             if(fwv.belongsToGroup)
             	fieldsWithGroups.add(fwv);  
             if(fwv.field.Update_On__c == true)
             	UpdateFieldName = fwv.field.name;
             if(f.Required__c)	            	
             	 hasRequired = true;
             	 	
             allFields.add(fwv);
        }
            
        //get a full list of all objecttokens in this org
        gd = Schema.getGlobalDescribe();
        //get a reference to the token related to the object referenced in the webform
        SObjectType sot = gd.get(form.Object_Name__c);
        //instantiate an object of this type
        try {
        	// SObjectInstance may also be passed to the form
        	if(sobjectInstance == null)
	            sobjectInstance = sot.newSObject();
        }
        
        //this happens when the object's API name doesn't exist, or has been removed from the profile access settings
        //Typically when admin's don't setup the webform editor correctly
        catch(System.NullPointerException ex) {
            ApexPages.addMessage(new ApexPages.Message(ApexPages.Severity.ERROR, 'The system can not create a form for : '+ form.Object_Name__c));
            return;
        }
        
        //if there is an existing object with default values for the form, we will load them
        if(form.Default_Record__c != null)
        {
        	try {
        		
	        	Map<String, SObjectField> fields = sot.getDescribe().fields.getMap();
	        	List<SObjectField> fieldtokens = fields.values();
	        	List<String> objectfields = new List<String>();
	
		        for(SObjectField fieldtoken:fieldtokens) {
		        	
		            DescribeFieldResult dfr = fieldtoken.getDescribe();
		            if(!dfr.isCreateable()) continue; // || dfr.isDefaultedOnCreate()
		            if((dfr.getName() == 'CreatedDate') || (dfr.getName() == 'LastModifiedDate') || (dfr.getName() == 'CreatedById') || (dfr.getName() == 'LastModifiedById')) continue;
		            if(dfr.getName() == 'OwnerId') continue;
		            if(dfr.getName() == 'Name') continue;

		            objectFields.add(dfr.getName());
		            
		        }
		        
		        String queryString = 'select id, ';
		        for(String obf : objectfields)
		        	queryString += obf + ', ';
		        queryString = queryString.substring(0,queryString.length()-2);
		        queryString += ' from ' + form.Object_Name__c + ' where id =\'' + form.Default_Record__c + '\'';
		        System.debug('QUERY:' + queryString);
	        	List<SObject> defaults = Database.query(queryString);
	        	for(String obf : objectFields)
	        	 	if(defaults[0].get(obf) != null)
		        		sobjectInstance.put(obf, defaults[0].get(obf));
        	}
        	catch (Exception e)         	{
        		
        		System.debug('Could not load default values: ' + e ); 
        	}
        }
        
        
        //URL passed Params not currently supported in Formation
       /* 
        //override the field value with whatever has been passed in the URL

        Map<String,String> params = System.currentPageReference().getParameters();
        //create a map of the fields
        Map<String,Form_Field__c> mfields = new Map<String,Form_Field__c>(); 
        for(Form_Field__c f:fields) {
            mfields.put(f.Name, f);
        }
       
       for(String p:params.keySet()) {
            //check if the passed param matches one of the field names
            Form_Field__c f = mfields.get(p);
            //if a field matches, make it's value what was passed as value in the url parameter
            if(f != null) {        
                //  WebformUtils.setFormFieldValue(f, params.get(f.Name));
            }
        }*/
    }
    
    
    //fill the object with the correct field values and save it
    public PageReference saveObject() {
    	System.debug('Entering Save method');
    	String id;
    	List<sObject> sos;        
    	PageReference newPr;
    	
        try {
            //Boolean to keep validation status
            Boolean valid = true;
            //loop over all the displayed fields
            for(Form_Field__c ff:fields) {
                String fieldtype = ff.Type__c;
                String name = ff.Name;
                //Object value = WebformUtils.getFormFieldValue(ff);
                Object value;  
                //Check if required fields have values
                try {
	                System.debug('Checking validity. Field:' + name + 'Required:' + ff.Required__c + ' Value:' + (String) value);     
                	String v = (String) value;
                	if (v == '' || v == null || v.length() < 1)
                		value = null;
                }
                catch (TypeException te)
                {
                	
                }
                if((value == null) && ff.Required__c  ) {
                	System.debug('value is null and required. Adding message!');
                    ApexPages.Message reqMsg = new ApexPages.Message(ApexPages.Severity.ERROR, ff.Label__c + ' is a required field.');
                    ApexPages.addMessage(reqMsg);               
                    valid = false;
                }           
                if(value != null) sobjectInstance.put(name, value);     
            }
            if(valid) {
                
		    	if(UpdateFieldName != null)
		    	{
				    try {
					         String queryString = 'Select Id from ' + sobjectInstance.getSObjectType() + ' where '  + UpdateFieldName + '=\'' + sobjectInstance.get(UpdateFieldName) + '\' limit 1';
					       	 System.debug('Attempting to update existing object. Query:' + queryString);
					       	 sos = Database.query(queryString);  
					       	 if(sos.size() > 0)
					       	 {
						         SObject newSObjectInstance = sos[0];
								 Map<String, Schema.SObjectField> m = SObjectInstance.getSObjectType().getDescribe().fields.getMap();
								 List<String> fieldNames = new List<String>();
								 fieldNames.addAll(m.keySet());
						
						         for(Integer i=0; i < fieldNames.size(); i++)
						         {
						         	String fieldName = fieldNames.get(i);
						         	if(fieldName != 'id')
						         	{
							         	Object o = sObjectInstance.get(fieldName);
							         	if (o!=null)
							         		newSObjectInstance.put(fieldName,o);
						         	}
						         }
						         sObjectInstance = newSObjectInstance;
					       	 }
					         
					    }
				        catch(Exception e)
				        {
				        	System.debug('Error while attempting to Update existing object' + e);
				        }
		    	}

	            System.debug('Ready to save sobject instance');
	
                upsert sobjectInstance;
		    	
		    	pageController.myObject = sobjectInstance;
		    	pageController.ecSave();
		    	
                String retUrl = form.Return_URL__c;
                //accept url's with or without http://
                if (retUrl != null && retUrl.length() > 3)
                {
		            if(!form.Return_URL__c.startsWith('http://')) retUrl = 'http://'+form.Return_URL__c; //this slightly different from the component version that takes sites into account         
	                newPr =  new PageReference(retUrl);    
                }

                
                         
            }
        } catch(Exception ex) {
            ApexPages.addMessages(ex);
            System.debug('Exception occured '+ex.getMessage());
        }
        try
            { 
                 insert new Task(
                 WhoID                         = (String) sobjectInstance.get('id'),
                 Subject                       = form.Title__c,
                 ActivityDate                  = Date.today(),  // or System.now()
                 Status                        = 'Completed',
                 Priority                      = 'Normal',
                 OwnerId 					   = '005A0000000QrzT'  
                );
            }
            catch(NullPointerException e)
             {
             	System.debug('Failed to insert Task');
            }  
        
        return newPr;
    }

	public Boolean getEmpty()
	{
		return (allFields == null || allFields.size() == 0);
		
	}
	
	public String getStylesheet()
	{
		String url = 'http://ajax.googleapis.com/ajax/libs/jqueryui/1.8/themes/';
		if(form.Style__c == 'Cupertino')
			url += 'cupertino';
		else if(form.Style__c == 'Smoothness')
			url += 'smoothness';
		else if(form.Style__c == 'UI Darkness')
			url += 'ui-darkness';
		else if(form.Style__c == 'Redmond')
			url += 'redmond';
		else
			url += DEFAULT_THEME;
			
		url += '/jquery-ui.css';
		
		return url;			

	}  

    class FieldWrapper
    {
        public Form_Field__c field {get; set;}
        public Integer order {get; set;}
        public Boolean hasValRules {get; set;}
        public Boolean belongsToGroup {get; set;}
        public String jqueryValidation {get; set;}
		public List<ShowRule> showRules { get; set; }


          
        public FieldWrapper(Form_Field__c field)
        {
            this.field = field;
            if(field.Order__c != null)
	            order = field.Order__c.intValue();  
            jqueryValidation = WebFormUtils.getJQueryValidation(field);  
            if (jqueryValidation == '')
                hasValRules = false;
            else
                hasValRules = true; 
            if (field.Group__c != null && field.Group__c.length() > 2)       
            	belongsToGroup = true;    
            else          
            	belongsToGroup = false;    
			
			showRules = new List<ShowRule>();
            List<Field_Show_Rule__c> fsrs = [SELECT id, name, value_to_show__c from Field_Show_Rule__c where Form_Field__c =: field.id];
		    for(Field_Show_Rule__c fsr : fsrs)  
		    	showRules.add(new ShowRule(fsr));   
		    	 	
           	//System.debug('Show rules run ' + showRules.size() + ' record returned');
                        
        }    
        
    public Boolean getHasMessages() {
    
    	return ApexPages.hasMessages();
    	
    }
    
    public Boolean getHasShowRules()
    {
    	if (showRules == null || showRules.size() == 0)
    		return false;
    	else
    		return true;
    }
    }


    
}

//  Copyright (c) 2009, David Van Puyvelde, Sales Engineering, Salesforce.com Inc.
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:
//  Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer. 
//  Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
//  Neither the name of the salesforce.com nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission. 
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES,
//  INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, 
//  SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; 
//  LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN 
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, 
//  EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.