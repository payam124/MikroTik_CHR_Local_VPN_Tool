{
    :if ([:len [/system resource get board-name]] > 0 && [/system resource get board-name] ~ "CHR") do={
        :if ([/system license get level] = "free") do={
            :local msg "system does not have license and it is CHR, so apply for a alicense"
            :log info $msg
            :put $msg
            /terminal style error ; :put "system does not have license and it is CHR, so apply for a alicense"
            /system license renew account=$AAMikroTikAccount password="$AAMikroTikPass" level=$AACHRLicenseLevel
        } else={
            :local msg "CHR instance already licensed."
            :log info $msg
            :put $msg
        }
    } else={
        :local msg "This is not a CHR instance."
        :log info $msg
        :put $msg
    }
}