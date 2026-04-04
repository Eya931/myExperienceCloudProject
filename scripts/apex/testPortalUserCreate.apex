CreatePortalUserAndNotify.Request r = new CreatePortalUserAndNotify.Request();
r.contactId = '003gL00000ZefMsQAJ';
r.email = 'eyaboudidah00@gmail.com';
r.firstName = 'Mohsen';
r.lastName = 'Rebhi';
r.profileId = '00egL0000085KoNQAU';
r.username = 'eyaboudidah00@gmail.com.talan';
List<CreatePortalUserAndNotify.Result> res = CreatePortalUserAndNotify.createUser(new List<CreatePortalUserAndNotify.Request>{r});
System.debug('RESULT=' + res[0].success + ' | USER=' + res[0].userId + ' | ERR=' + res[0].errorMessage);
