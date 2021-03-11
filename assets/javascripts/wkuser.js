
$(function() {
  var accNo = document.getElementById('erpmineuser_account_number');
  var ssId = document.getElementById('erpmineuser_ss_id');
  if (accNo && accNo.disabled && accNo.value.length > 4) {
      accNo.value = new Array(accNo.value.length-3).join('x') + accNo.value.substr(accNo.value.length-4, 4);
  }
  if (ssId && ssId.disabled && ssId.value.length > 4) {
    ssId.value = new Array(ssId.value.length-3).join('x') + ssId.value.substr(ssId.value.length-4, 4);
  }
});

function getEmpDetails(){
  const id = $('#hiring_employee').val();
  if(id){
    $.ajax({
      url: "/wkreferrals/getEmpDetails?id="+id,
      beforeSend: function(){
        $('#ajax-indicator').show();
      },
      success: function(data){
        $('#ajax-indicator').hide();
        console.log(data.contact);
        setDetails(data);
      }
    });
  }
  else{
    setDetails(null);
  }
}

function setDetails(referral){
  const elements = [
    {id: 'user_firstname', type: 'contact', key: 'first_name'},
    {id: 'user_lastname', type: 'contact', key: 'last_name'},
    {id: 'user_login', type: 'contact', key: 'last_name'},
    {id: 'work_phone', type: 'address', key: 'work_phone'},
    {id: 'mobile', type: 'address', key: 'mobile'},
    {id: 'email', type: 'address', key: 'email'},
    {id: 'fax', type: 'address', key: 'fax'},
    {id: 'website', type: 'address', key: 'website'},
    {id: 'address1', type: 'address', key: 'address1'},
    {id: 'address2', type: 'address', key: 'address2'},
    {id: 'city', type: 'address', key: 'city'},
    {id: 'state', type: 'address', key: 'state'},
    {id: 'country', type: 'address', key: 'country'},
    {id: 'pin', type: 'address', key: 'pin'},
    {id: 'attachment_ids', type: 'attachment_ids', key: 'attachment_ids'},
    {id: 'erpmineuser_source_type', type: 'source_type', key: 'source_type'},
    {id: 'erpmineuser_source_id', type: 'source_id', key: 'source_id'}
  ];

  elements.map((ele)=>{
    if(referral && referral[ele.type] && (referral[ele.type][ele.key] || ele.type == ele.key)){
      let value = ele.type == ele.key ? referral[ele.type] : referral[ele.type][ele.key];
      $('#'+ele.id).val(value);
    }
    else{
      $('#'+ele.id).val(null);
    }
  });
}