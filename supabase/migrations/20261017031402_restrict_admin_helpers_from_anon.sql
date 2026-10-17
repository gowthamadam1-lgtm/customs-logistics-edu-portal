-- Signed-out visitors (anon) have no reason to call these admin helpers.
-- is_admin(uuid) just reports whether an id is an admin; admin_overview_stats()
-- already refuses non-admins inside the function. Removing anon's ability to
-- call them at all closes the exposure the security advisor flagged.
-- Signed-in users (authenticated) keep access: the row-level rules call
-- is_admin during normal reads, and the admin dashboard calls both.
revoke execute on function public.is_admin(uuid) from anon;
revoke execute on function public.admin_overview_stats() from anon;
