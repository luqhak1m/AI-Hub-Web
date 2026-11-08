/// The job seeker's areas, in sidebar order.
enum UserSection { home, jobs, applications, resumes, assessment, notifications, profile }

/// Opens an area. [arg] preselects something in it (e.g. a job id on Jobs).
typedef OpenSection = void Function(UserSection section, {Object? arg});
