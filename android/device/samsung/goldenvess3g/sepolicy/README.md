# SELinux policy - TODO (BLOCKED on a kernel decision)

The stock kernel is built without SELinux (`CONFIG_SECURITY` off, VERIFIED). Android 7's init expects a policy.
The community trees' `sepolicy/` directories (I8200N lineage, written for CM 11/12) were not carried over: they target a
different Android version and a different model.

Next steps: (1) decide kernel SELinux (permissive first or off, see ../kernel/README.md); (2) write device policy only for
services that actually run, starting from none; (3) never ship permissive without saying so.
