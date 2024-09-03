ad_library {

    APM Callbacks

}

namespace eval ::richtext::tinymce {}
namespace eval ::richtext::tinymce::apm {}

ad_proc -private ::richtext::tinymce::apm::after_upgrade {
    -from_version_name
    -to_version_name
} {
    After-upgrade callback.
} {
    apm_upgrade_logic \
	-from_version_name $from_version_name \
	-to_version_name $to_version_name \
	-spec {
	    1.0.0 1.0.1 {
                ns_log notice \
                    ::richtext::tinymce::apm::after_upgrade \
                    -from_version_name $from_version_name \
                    -to_version_name $to_version_name \
                    START

                if {[db_0or1row lookup_parameter {
                    select parameter_id from apm_parameters
                    where package_key = 'richtext-tinymce'
                      and parameter_name = 'TinyMCEDefaultConfig'
                      and scope = 'instance'
                }]} {
                    ns_log notice \
                        ::richtext::tinymce::apm::after_upgrade \
                        -from_version_name $from_version_name \
                        -to_version_name $to_version_name \
                        apm_parameter_unregister \
                        -parameter_id $parameter_id
                    apm_parameter_unregister -parameter_id $parameter_id
                }

                ns_log notice \
                    ::richtext::tinymce::apm::after_upgrade \
                    -from_version_name $from_version_name \
                    -to_version_name $to_version_name \
                    END
            }
	}
}
