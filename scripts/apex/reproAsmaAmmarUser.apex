CreatePortalUserAndNotify.Request r = new CreatePortalUserAndNotify.Request();
r.contactId = '003gL00000ZfJTyQAN';
r.email = 'eyaboudidah00@gmail.com';
r.firstName = 'Asma';
r.lastName = 'Ammar';
r.profileId = '00egL0000085KoNQAU';
r.username = 'asma.ammarjtyqan@gmail.com';
List<CreatePortalUserAndNotify.Result> res = CreatePortalUserAndNotify.createUser(new List<CreatePortalUserAndNotify.Request>{r});
System.debug('RESULT=' + res[0].success + ' | USER=' + res[0].userId + ' | ERR=' + res[0].errorMessage);
