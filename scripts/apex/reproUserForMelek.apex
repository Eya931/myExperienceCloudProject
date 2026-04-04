CreatePortalUserAndNotify.Request r = new CreatePortalUserAndNotify.Request();
r.contactId = '003gL00000Zf9cgQAB';
r.email = 'eyaboudidah00@gmail.com';
r.firstName = 'Melek';
r.lastName = 'Dridi';
r.profileId = '00egL0000085KoNQAU';
r.username = 'melek.dridi@gmail.com';
List<CreatePortalUserAndNotify.Result> res = CreatePortalUserAndNotify.createUser(new List<CreatePortalUserAndNotify.Request>{r});
System.debug('RESULT=' + res[0].success + ' | USER=' + res[0].userId + ' | ERR=' + res[0].errorMessage);
