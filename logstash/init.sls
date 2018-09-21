{%- from tpldir + '/map.jinja' import logstash with context %}

{%- if logstash.use_upstream_repo %}
include:
  - .repo
{%- endif %}

logstash-pkg:
  pkg.{{logstash.pkgstate}}:
    - name: {{logstash.pkg}}
    {%- if logstash.use_upstream_repo %}
    - require:
      - pkgrepo: logstash-repo
      - pkg: {{ logstash.java }}
    {%- endif %}

{{ logstash.java }}:
  pkg.installed

# This gets around a user permissions bug with the logstash user/group
# being able to read /var/log/syslog, even if the group is properly set for
# the account. The group needs to be defined as 'adm' in the init script,
# so we'll do a pattern replace.

{% if salt['grains.get']('init' , None) != 'systemd'%}
{%- if salt['grains.get']('os', None) == "Ubuntu" %}

add adm group to logstash service account:
  user.present:
    - name: logstash
    - remove_groups: False
    - groups:
      - logstash
      - adm
    - require:
      - pkg: logstash-pkg
{%- endif %}
{% endif %}

{%- if logstash.inputs is defined %}
logstash-config-inputs:
  file.managed:
    - name: /etc/logstash/conf.d/01-inputs.conf
    - user: root
    - group: root
    - mode: 755
    - source: salt://{{ tpldir }}/files/01-inputs.conf
    - template: jinja
    - context:
      tpldir: {{ tpldir }}
    - require:
      - pkg: logstash-pkg
{%- else %}
logstash-config-inputs:
  file.absent:
    - name: /etc/logstash/conf.d/01-inputs.conf
{%- endif %}

{%- if logstash.filters is defined %}
logstash-config-filters:
  file.managed:
    - name: /etc/logstash/conf.d/02-filters.conf
    - user: root
    - group: root
    - mode: 755
    - source: salt://{{ tpldir }}/files/02-filters.conf
    - template: jinja
    - context:
      tpldir: {{ tpldir }}
    - require:
      - pkg: logstash-pkg
{%- else %}
logstash-config-filters:
  file.absent:
    - name: /etc/logstash/conf.d/02-filters.conf
{%- endif %}

{%- if logstash.outputs is defined %}
logstash-config-outputs:
  file.managed:
    - name: /etc/logstash/conf.d/03-outputs.conf
    - user: root
    - group: root
    - mode: 755
    - source: salt://{{ tpldir }}/files/03-outputs.conf
    - template: jinja
    - context:
      tpldir: {{ tpldir }}
    - require:
      - pkg: logstash-pkg
{%- else %}
logstash-config-outputs:
  file.absent:
    - name: /etc/logstash/conf.d/03-outputs.conf
{%- endif %}

logstash-svc:
  service.running:
    - name: {{logstash.svc}}
    - enable: true
    - require:
      - pkg: logstash-pkg
    - watch:
      - file: logstash-config-inputs
      - file: logstash-config-filters
      - file: logstash-config-outputs
