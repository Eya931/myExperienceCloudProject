CreatePortalUserAndNotify.Request r = new CreatePortalUserAndNotify.Request();
r.contactId = '003gL00000ZefMsQAJ';
r.email = 'eyaboudidah00@gmail.com';
r.firstName = 'Test';
r.lastName = 'Dup';
r.profileId = '00egL0000085KoNQAU';
r.username = 'eyaboudidah00@gmail.com.talan';
List<CreatePortalUserAndNotify.Result> res = CreatePortalUserAndNotify.createUser(new List<CreatePortalUserAndNotify.Request>{r});
System.debug(res[0].success + ' | ' + res[0].errorMessage);
