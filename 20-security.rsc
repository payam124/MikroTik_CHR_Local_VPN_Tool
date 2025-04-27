
{
   /ip service set port=$AASSHPort [find name=ssh]
   /ip service set port=$AAWinboxPort [ find name=winbox ]

   #/user group
   #add name=user_limited_access policy=local,write,password,web,sensitive,!telnet,!ssh,!ftp,!reboot,!read,!policy,!test,!winbox,!sniff,!api,!romon,!rest-api skin=user
   :put "### add user group"
   :local userGroupPolicy "local,reboot,read,write,policy,password,web,sensitive,!telnet,!ssh,!ftp,!test,!winbox,!sniff,!api,!romon,!rest-api"

   :if ([:len [/user group find name="user_limited_access"]] = 0) do={
      :log info "Creating user group: user_limited_access"
      /user group add name=user_limited_access policy=$userGroupPolicy skin=user
      :log info "User group user_limited_access created successfully."
   } else={
      :log info "User group user_limited_access already exists. Updating policy."
      /user group set [find name="user_limited_access"] policy=$userGroupPolicy skin=user
      :log info "Policy updated for user group user_limited_access."
   }
   :put "### add new admin"
   :if ([:len [/user find name=$AAnewAdminUser]] = 0) do={
      :log info "Creating new user: $AAnewAdminUser"
      /user add name=$AAnewAdminUser password="$AAnewAdminPass" group=full
      :log info "User $AAnewAdminUser created successfully."
   } else={
      :log info "User $AAnewAdminUser already exists. Updating password."
      /user set [find name=$AAnewAdminUser] password="$AAnewAdminPass"
      :log info "Password updated for user $AAnewAdminUser."
   }

   :put "### add new user"
   :if ([:len [/user find name=$AAUserUser]] = 0) do={
      :log info "Creating new user: $AAUserUser"
      /user add name=$AAUserUser password="$AAuserPass" group=user_limited_access
      :log info "User $AAUserUser created successfully."
   } else={
      :log info "User $AAUserUser already exists. Updating password."
      /user set [find name=$AAUserUser] password="$AAuserPass" group=user_limited_access
      :log info "Password updated for user $AAUserUser."
   }

   :do {

      /tool fetch url=$AASSHKeyLink output=file dst-path=ssh.key
      :delay 4
      # add ssh key
      /user ssh-keys import public-key-file=ssh.key user=$AAnewAdminUser

      :put "##ssh-key importead an added for $AAnewAdminUser"
      
      :do {/file remove ssh.key} on-error={:put "ssh key already removed"}
      #allow password based login as well

      /ip/ssh/set always-allow-password-login=yes
      :put "ssh login with user and key activated"
   } on-error= {
      /terminal style error ; :put "error fetching the ssh key, importing it or allocating it to the user"
   }
   /terminal style none; :put "##end"

}