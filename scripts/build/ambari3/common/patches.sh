# 单点维护补丁清单（按顺序）
# 用绝对/相对路径都行，建议使用 repo 根为基准的相对路径
patch_files=(
  "/scripts/build/ambari3/common/patch2_0_0/patch0-ALL-IN-ONE.diff"
  "/scripts/build/ambari3/common/patch2_0_0/patch1-START-LOGBACK-LOGGER.diff"
  # 2.1.0
  "/scripts/build/ambari3/common/patch2_1_0/patch0-DEBIAN-BASE-SUP.diff"
  "/scripts/build/ambari3/common/patch2_1_0/patch1-DEBIAN-BASE-SUP.diff"
  "/scripts/build/ambari3/common/patch2_1_0/patch2-DEBIAN-DOLPHIN-RANGER-SUP.diff"
  "/scripts/build/ambari3/common/patch2_1_0/patch3-DEBIAN-FINAL-SUP.diff"
  # 2.2.0
  "/scripts/build/ambari3/common/patch2_2_0/patch0-KYLIN-BASE-SUP.diff"
  "/scripts/build/ambari3/common/patch2_2_0/patch1-KYLIN-ALL-COMPONENT-SUP.diff"
  # 2.2.1
  "/scripts/build/ambari3/common/patch2_2_1/patch0-KERBEROS-SUP-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch1-ATLAS-RHEL-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch2-VIEWS-COMPILE-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch3-HUDI-PAIMON-BUGS-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch4-KERBEROS-KAFKA-SOLR-HIVE-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch5-KERBEROS-HCAT-ATLAS-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch6-KERBEROS-LIVY-TRINO-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch7-KERBEROS-HUDI-PAIMON-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch8-KERBEROS-CELEBORN-HDFS.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch9-KERBEROS-RANGER-DROIS-SOLR-ZK.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch10-KERBEROS-IMPALA-HIVE-HDFS.diff"
  "/scripts/build/ambari3/common/patch2_2_1/patch11-KERBEROS-HA-IM-RG-OPTI.diff"
   # 2.2.2
  "/scripts/build/ambari3/common/patch2_2_2/patch0-ALLUXIO-HUE-SUP.diff"
  "/scripts/build/ambari3/common/patch2_2_2/patch1-WEBCHECK-UI-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_2/patch2-KNOX-ARCH-OPTIMIZED.diff"
  "/scripts/build/ambari3/common/patch2_2_2/patch3-TRINO-KERBEROS-STATUS-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_2/patch4-RANGER-PIPLINE-FIXED.diff"
  "/scripts/build/ambari3/common/patch2_2_2/patch5-KNOX-HIVE-SUP-FIXED.diff"
)


