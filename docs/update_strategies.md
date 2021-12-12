
Update strategies
=================

__Beware:__ This project is a crutch for people who cannot implement
the efficient approach due to non-programming constraints.
(Which can sometimes be found in some small companies.)

Of course you can use parts of this project to implement the efficient
approach, but there are more convenient options available.



The forgetful approach  (this project)
--------------------------------------

### Strategy

(Re-)Assemble your required docker environment each time you need it.

### Benefits

* Sneaky:
  Integrates as part of your project, in the same repo,
  which might save you some buerocracy effort.
* Undemanding:
  Works on the lowest common ground, i.e. any docker-based CI,
  no additional infrastructure required.
  * Overlaps with the "Sneaky" benefit.
  * Lazy update checking:
    If you set it up to always install the latest versions of everything,
    it may be acceptable to not actively monitor upstream releases.
* Easier portability:
  Depending on where you clone this repo from, that cloning URL may be
  longer-lived than your own repo URLs.

### Drawbacks

* Wasteful: The repeated work wastes
  * developer time
  * machine time
  * electrical power.
* Brittle:
  Relies heavily on connectivity to and availability of 3rd-party services.
  (Might be less of a problem in developed countries with ubiquitous internet
  coverage.)
  * Could be mitigated by hosting the ingredients on your own infrastructure.
    However, if you can do that, it's likely easy to host the result as well.



The resource efficient approach
-------------------------------

### Strategy

(Re-)Assemble your required docker environment each time there are
relevant upstream updates, or on a fixed schedule.

### Benefits

* Conserves scarce resources, especially human life time.
* Quicker CI cycles.
  * Helps developers stay on focus ("in the flow").
* Quicker deployment into production.
  * On deploy, you only need to build the project-specific parts.
* Reliability:
  When you host your resulting docker images on your own infrastructure,
  your CI works even in case of broken uplink.
* Security:
  Once you've audited a resulting docker image, you can rely on it in
  all subsequent CI runs.

### Drawbacks

* Needs docker image hosting:
  For FOSS projects, there are many free services that offer it
  (e.g. GitHub or GitLab), but you have to set them up initially.
* Needs monitoring:
  You need proper monitoring or scheduling infrastructure.
  * Sometimes you know a person who already monitors the upstream anyway,
    then they can kick your update mechanism into action.
  * Otherwise you'll need to setup some automated service, e.g. cron
    or a weekly Github Actions task.
















