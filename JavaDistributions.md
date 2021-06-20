# Java Distributions
This document has nothing to do with using YAMDI. Rather, it is a deep dive into the different Java distributions that could possibly pertain to running server software for Minecraft: Java Edition.

Minecraft itself, and most server software for it are written in the [Java programming language](https://en.wikipedia.org/wiki/Java_(programming_language)).

Programs written in Java are compiled not to architecture-specific [machine code](https://en.wikipedia.org/wiki/Machine_code), but to an intermediate representation, [Java bytecode](https://en.wikipedia.org/wiki/Java_bytecode).

Programs compiled to Java bytecode are executed by the [**Java Virtual Machine (JVM)**](https://en.wikipedia.org/wiki/Java_Virtual_Machine), which contains the crucial [Java Class loader](https://en.wikipedia.org/wiki/Java_Class_loader).

The necessity for a mechanism to interpret and/or recompile Java bytecode at runtime naturally leads to a discussion of Java not just as a programming language, but as a [software-platforms](https://en.wikipedia.org/wiki/Java_(software_platform)). The different types of Java platforms all provide specifications for the following:
- The [Java Language Specification](https://en.wikipedia.org/wiki/Java_Language_Specification), necessary for implementing a compiler for Java code. Although most (if not all) of the software we'll be running in the JVM is written in Java, there are [many more languages](https://en.wikipedia.org/wiki/List_of_JVM_languages) that use it - you may have heard of Kotlin or Haxe.
- The [Java Virtual Machine Specification](https://en.wikipedia.org/wiki/Java_Virtual_Machine_Specification), necessary for running programs written in JVM languages.
- The desired [APIs](https://en.wikipedia.org/wiki/API).

The  are *specification* for the different platforms that Java targets. The different Java platforms are:
- [**Java Platform, Standard Edition (Java SE)**](https://en.wikipedia.org/wiki/Java_Platform,_Standard_Edition), formerly **Java 2 Platform, Standard Edition (J2SE)**, broadly targetting desktop and server environments. This defines the same Java Language Specification, the Java Virtual Machine Specification that is used by all java platforms. This also defines general-purpose APIs.
- [**Java Platform, Micro Edition (Java ME)**](https://en.wikipedia.org/wiki/Java_Platform,_Micro_Edition), formerly **Java 2 Platform, Micro Edition (J2ME)**, targetting environments for embedded and mobile devices.
- [**PersonalJava**](https://en.wikipedia.org/wiki/PersonalJava), now discontinued, targetting environments for embedded and mobile devices.
- [**Jakarta EE**](https://en.wikipedia.org/wiki/Jakarta_EE), formerly **Java Platform, Enterprise Edition (Java EE)** and **Java 2 Platform, Enterprise Edition (J2EE)**
- [**Java Card**](https://en.wikipedia.org/wiki/Java_Card), targetting [smart cards](https://en.wikipedia.org/wiki/Smart_card).
- [**JavaFX**](https://en.wikipedia.org/wiki/JavaFX) [used to be](https://docs.oracle.com/javaee/6/firstcup/doc/gkhoy.html) it's own platform, but is now a part of Java SE.

The Java SE specification has all of the APIs that are needed for running Minecraft servers, and therefore is the only one that we care about or will refer to here.

The [**Java Development Kit (JDK)**](https://en.wikipedia.org/wiki/Java_Development_Kit) is an *implementation* of a given Java platform *specification*. To take the most popular one as an example, the OpenJDK Java Development Kit *implements* the Java SE *specification*. If the developer and/or distributor would like to, they may also ship the [**Java Runtime Environment (JRE)**](https://en.wikipedia.org/wiki/Java_virtual_machine#Java_Runtime_Environment), a distribution containing only what's necessary to run Java applications, including the JVM and the [**Java Class Library (JCL)**](https://en.wikipedia.org/wiki/Java_Class_Library). The JRE may be considered a subset of the JDK. For more reading, see [this](https://stackoverflow.com/questions/1906445/what-is-the-difference-between-jdk-and-jre) Stack Overflow thread and [this](https://java.com/en/download/help/techinfo.html) Oracle page. Oracle prefers that the term JDK refers to JDKs for Java SE in particular. Whether a distributor distributes a JRE at all is an implementation detail; not all of them do.

At first, the two options for running Java options were using a JDK distributed by Sun (later, Oracle), or using a [free implementation](https://en.wikipedia.org/wiki/Free_Java_implementations#Mid-1990s_to_2006), none of which had complete feature parity. In 2006, however, Sun [committed](https://web.archive.org/web/20080513023707/http://www.sun.com/2006-1113/feature/story.jsp) to open sourcing the JDK, with this open-source implementation called OpenJDK.

However, there are parts of the JDK that have still not been released as free software. In response to this, Red Had started [**IcedTea**](https://en.wikipedia.org/wiki/IcedTea), a combination of the free parts of OpenJDK, and the already existing [**GNU Classpath**](https://en.wikipedia.org/wiki/GNU_Classpath), for a wholly free distribution.

## JVMs
Although HotSpot is often the dominant JVM, there are other JVMs that are worth knowing about.

### HotSpot
[HotSpot](http://openjdk.java.net/groups/hotspot/) is the JVM maintained by Oracle as a part of the OpenJDK project, historically the "default".

### Eclipse Open J9
[Eclipse OpenJ9](https://www.eclipse.org/openj9/), formerly IBM J9 is an alternate JVM maintained by Eclipse targetting a lower memory footprint and faster startup.

### GraalVM
[GraalVM](https://www.graalvm.org/) is a JVM based off of HotSpot adding support for additional languages, including a new JIT compiler for Java targetting increased performance.

### JamVM
[JamVM](http://jamvm.sourceforge.net/) is a JVM designed to be extremely small, and maintain compatibility with both OpenJDK and GNU Classpath.

### Azul Platform Prime
[Azul Platform Prime](https://www.azul.com/products/prime/) is a proprietary JVM created by [Azul](https://www.azul.com/) featuring [ReadyNow!](https://www.azul.com/products/components/readynow/) for faster startup times, the [Falcon JIT compiler](https://www.azul.com/products/components/falcon-jit-compiler/) for performance, and the [C4 Garbage Collector](https://www.azul.com/products/components/pgc/), the Continuously Concurrent Compacting Collector, for less interruptions.

### Maxine Virtual Machine
[Maxine Virtual Machine](https://github.com/beehive-lab/Maxine-VM) is an experimental JVM whose parts served as the basis for GraalVM.

### Jikes RVM
[Jikes RVM](https://www.jikesrvm.org/) is an older JVM designed for operation with [Apache Harmony](http://harmony.apache.org/) and GNU Classpath.

## JDKs
These days, nearly every Java distribution is based on the OpenJDK source code. Regardless of what patches they may apply, in order for a JDK to be deemed "Java SE Compatible", every distributor must undergo a rigorous verification process, the [Technology Compatibility Kit (TCK)](https://en.wikipedia.org/wiki/Technology_Compatibility_Kit).

Without further ado, let's look through a bunch of Java distributions! We will be referring to the amazing articles ["Java is Still Free"](https://medium.com/@javachampions/java-is-still-free-2-0-0-6b9aa8d6d244) and ["Time to look beyond Oracle's JDK](https://blog.joda.org/2018/09/time-to-look-beyond-oracles-jdk.html) throughout. For further reading, see the StackOverflow question ["Difference between OpenJDK and Adoptium/AdoptOpenJDK"](https://stackoverflow.com/q/52431764), and [this](https://www.azul.com/products/core/jdk-comparison-matrix/) Azul page. For a broad comparison of all of the OpenJDK options, see [this](https://en.wikipedia.org/wiki/OpenJDK#OpenJDK_builds) table.

If unspecified, the builds only provide support for the HotSpot JVM, are TCK tested, are released with a permissive license, and provide updates long term support releases.

### Building OpenJDK Yourself
OpenJDK is open-source, so, sure, [you can build it yourself](https://medium.com/@javachampions/java-is-still-free-2-0-0-6b9aa8d6d244#c839) if you really want! No support provided.

### Adoptium / AdoptOpenJDK
[Adoptium](https://adoptium.net/), formerly [AdoptOpenJDK](https://adoptopenjdk.net/), provides [Adoptium builds](https://adoptium.net/releases.html), offering HotSpot builds unmodified from the OpenJDK source, and OpenJ9 builds still based on the OpenJDK source, both not TCK tested. Free community support [is provided](https://adoptium.net/support.html#community-support), and commercial support is providede by IBM and jClarity.

### Oracle OpenJDK
[Oracle](https://www.oracle.com) provides [Oracle OpenJDK](http://jdk.java.net/), built from unmodified OpenJDK source, TCK tested. No support is provided, nor is LTS.

### ojdkbuild
[ojdkbuild](https://github.com/ojdkbuild) provides [ojdkbuilds builds](https://github.com/ojdkbuild/ojdkbuild), built from unmodified OpenJDK source, not TCK tested. No support is provided.

### Oracle JDK builds
Oracle provides [Oracle JDK](https://www.oracle.com/java/technologies/javase-downloads.html), built from OpenJDK source modified with [cosmetic and packaging changes](https://blogs.oracle.com/java-platform-group/oracle-jdk-releases-for-java-11-and-later), with commercial licensing. [Take care with this!](https://blog.joda.org/2018/09/do-not-fall-into-oracles-java-11-trap.html).

### Microsoft build of OpenJDK
[Microsoft](https://www.microsoft.com/) provides the [Microsoft Build of OpenJDK](https://www.microsoft.com/openjdk), built from OpenJDK source that may have [backported fixes and enhancements](https://docs.microsoft.com/en-us/java/openjdk/overview). Commercial support is available through [Azure](https://azure.microsoft.com/).

### Red Hat build of OpenJDK
[Red Hat](https://www.redhat.com/) provides the [Red Hat build of OpenJDK](https://developers.redhat.com/products/openjdk/overview), built from OpenJDK source that may have [backported fixes and enhancements](https://access.redhat.com/articles/1299013). Commercial support is available.

### Amazon Corretto
[Amazon](https://www.amazon.com/) provides [Amazon Corretto](https://aws.amazon.com/corretto/), built from OpenJDK source modified with security and performance patches. Commercial support is available through [Amazon Web Services](https://aws.amazon.com/).

### OpenLogic OpenJDK
[OpenLogic](https://www.openlogic.com/) provide [OpenJDK builds](https://www.openlogic.com/openjdk-downloads), built from OpenJDK source modified with security patches. Commercial support is available.

### Bellsoft Liberica JDK
[Bellsoft](https://bell-sw.com/) provides [Liberica OpenJDK](https://bell-sw.com/pages/libericajdk/), built from OpenJDK source with security patches and critical updates shared with the JetBrains Runtime. Commercial support is available.

### JetBrains Runtime
[JetBrains](https://www.jetbrains.com/) provides [JetBrains Runtime](https://confluence.jetbrains.com/display/JBR/JetBrains+Runtime), built from OpenJDK source modified with [bug fixes](https://confluence.jetbrains.com/display/IDEADEV/JetBrains+Runtime+Environment) as well as security patches and critical updates shared with the Bellsoft Liberica JDK. Commercial support is not provided.

### SapMachine
[SAP](https://www.sap.com/) provides [SapMachine](https://sap.github.io/SapMachine/), built from OpenJDK source modified with security patches. Commercial support is available for SAP customers.

### Alibaba Dragonwell8 JDK
[Alibaba](https://www.alibaba.com/) provides [Alibaba Dragonwell](http://dragonwell-jdk.io/), built from OpenJDK source optimized for scaling Java applications to tens of thousands of servers. Commercial support is not provided.

### IcedTea
Red Hat provides [IcedTea](https://openjdk.java.net/projects/icedtea/), historically built from OpenJDK source with replacements for encumbered proprietary components. Free community support is available.

### OpenJDK builds by Linux distributions
Most Linux distributions package OpenJDK themselves. Some can transparently opt to install IcedTea instead, but with the Java Web Start and the web browser plugins being the only lasting encumbered components that IcedTea fills in, these days they might just build OpenJDK as-is.

### IBM Java SDK
[IBM](https://www.ibm.com/) provides the [IBM Java SDK](https://www.ibm.com/support/pages/java-sdk), built from OpenJDK source [modified to use OpenJ9](https://www.ibm.com/docs/en/sdk-java-technology/8?topic=introduction-java-virtual-machine), with commercial licensing. Commercial support is available.

### GraalVM Community Edition
GraalVM, originally directly under Oracle, provides [GraalVM Community Edition](https://www.graalvm.org/downloads/), built from OpenJDK source modified to use GraalVM. Free community support is available.

### Oracle GraalVM Enterprise Edition
Oracle provides [GraalVM Enterprise Edition](https://www.oracle.com/java/graalvm/), built from OpenJDK source modified to use GraalVM with additional performance, security, and scalability patches, with commercial licensing. Commercial support is available.

### Azul Platform Core, Azul Platform Prime
Azul provides [Azul Platform Core](https://www.azul.com/downloads/), formerly Azul Zulu, built from OpenJDK source modified with security patches, as well as [Azul Platform Prime](https://www.azul.com/products/prime/), formerly Azul Zing, built from OpenJDK source modified with security patches with a [custom JVM based on Hostpot with a new garbage collector](https://en.wikipedia.org/wiki/Azul_Systems#Zing_JVM). Commercial support is available for both.

### Azul Zulu for Azure
Azul provides Azul Zulu (now Azule Platform Core) builds tailored to Microsoft's Azure platform, [Azul Zulu for Azure - Enterprise Edition](https://www.azul.com/downloads/azure-only/zulu/), built from OpenJDK source modified with security and compatibility patches. Commercial support is available. **This distribution is only intended for Java apps "developed and deployed in Microsoft Azure, Azure Stack, or Microsoft SQL Server," proceed with caution!**

## Docker Images
YAMDI aims to provide support for practically any Java image you can feed it. This section documents the various different Docker images that provide Java SE.

A couple of abbreviations used here are:
- FR: Feature Release
- MTS: Medium Term Support

### Oracle OpenJDK ([`library/openjdk`](https://hub.docker.com/_/openjdk)/[`library/java`](https://hub.docker.com/_/java))
This is Docker Hub's official image for the Oracle OpenJDK builds. That is, these images are officially endorsed and maintained by Docker, not necessarily Oracle.
- Java Versions: JDK and JRE 12 onwards
- JVMs: HotSpot
- OSs: Oracle Linux 7, Windows Server Core, Alpine Linux
- Architectures: `amd64`, `arm64v8`, `windows-amd64`

### AdoptOpenJDK Images from Docker Hub ([`library/adoptopenjdk`](https://hub.docker.com/_/adoptopenjdk))
This is the official Docker Hub maintained image for AdoptOpenJDK (now Adoptium) builds.
- Java Versions: JDK and JRE 8 onwards
- JVMs: HotSpot, OpenJ9
- OSs: Ubuntu, Windows Server Core
- Architectures: `amd64`, `arm32v7` (HotSpot only), `arm64v8` (HotSpot only), `pp64le`, `s380x`, `windows-amd64`

## AdoptOpenJDK Images from AdoptOpenJDK ([`adoptopenjdk/openjdk...`](https://hub.docker.com/u/adoptopenjdk))
This the official AdoptOpenJDK maintained image for AdoptOpenJDK (now Adoptium) builds.
- Java Versions: JDK and JRE 8 onwards
- JVMs: HotSpot, OpenJ9
- OSs: Too complicated to succinctly summarize - See [here](https://github.com/AdoptOpenJDK/openjdk-docker#official-and-non-official-images).
- Architectures: `amd64`, `arm64v8` (HotSpot only), `pp64le`, `s380x`

[Alpine Linux images for recent Java versions are now using native musl builds](https://github.com/AdoptOpenJDK/openjdk-docker#musl-libc-based-alpine-images).

### Amazon Corretto ([`library/amazoncorretto`](https://hub.docker.com/_/amazoncorretto))
This is Docker Hub and Amazon's official image for Amazon Corretto.
- Java Versions: JDK and JRE for latest LTS releases and lastest FR (see [here](https://aws.amazon.com/corretto/faqs/))
- JVMs: HotSpot
- OSs: [Amazon Linux 2](https://aws.amazon.com/amazon-linux-2/),  Alpine Linux
- Architectures: `amd64`, `arm64v8`

Although they don't seem to be pushed to Docker Hub, the GitHub repo for this image additionally supports building images with a slim Java installation, and using Debian as the base image.

### Oracle JDK ([`store/oracle/serverjre:8`](https://hub.docker.com/_/oracle-serverjre-8) (JRE 8), [`store/oracle/jdk:11`](https://hub.docker.com/_/oracle-jdk) (JDK 11))
[The Binary Code License Agreement prohibits anyone but Oracle from publicly distributing Oracle JDK](https://devops.stackexchange.com/a/434), so these are the definitive Docker images for Oracle JDK.
- Java Versions: JRE 8, JDK 11.
- JVMs: HotSpot
- OSs: Oracle Linux 7
- Architectures: `amd64`

### IBM Java SDK ([`library/ibmjava`](https://hub.docker.com/_/ibmjava))
This is Docker Huband IBM's official image for the IBM Java SDK.
- Java Versions: SDK 8 (Full JDK), JRE 8, SFJ 8 (Slim JRE)
- JVMs: OpenJ9
- OSs: Ubuntu, Alpine Linux
- Architectures: `amd64`, `i386`, `ppc64le`, `s390x`

The Alpine Linux configuration is not officially supported by the IBM Java SDK.

### Microsoft Build of OpenJDK ([`mcr.microsoft.com/openjdk/jdk`](https://hub.docker.com/_/microsoft-openjdk-jdk))
This is Microsoft's official image for the Microsoft Build of OpenJDK.
- Java Versions: JDK for latest LTS and latest FR (see [here](https://docs.microsoft.com/en-us/java/openjdk/support))
- JVMs: HotSpot
- OSs: Ubuntu, CBL-D (["a Microsoft compliant OS that will be used within Cloud Shell"](https://github.com/Azure/batch-shipyard/pull/354))
- Architectures: `amd64`

Although not pushed to Docker Hub, the GitHub repo also supports building for [CBL-Mariner](https://en.wikipedia.org/wiki/CBL-Mariner), Microsoft's internal Linux distribution for their server infrastructure.

### Azul Zulu ([`azul/zulu-openjdk-alpine`](https://hub.docker.com/r/azul/zulu-openjdk-alpine), [`azul/zulu-openjdk-centos`](https://hub.docker.com/r/azul/zulu-openjdk-centos), [`azul/zulu-openjdk-debian`](https://hub.docker.com/r/azul/zulu-openjdk-debian), [`azul/zulu-openjdk`](https://hub.docker.com/r/azul/zulu-openjdk))
This is Azul's official image for Azul Zulu (now Azul Platform Core).
- Java Versions: JDK for last LTS releases and last FR releases, and JRE for latest FR release (see [here](https://www.azul.com/products/azul-support-roadmap/))
- JVMs: HotSpot
- OSs: Alpine Linux, CentOS, Debian, Ubuntu
- Architectures: `amd64`

The Alpine Linux image uses a musl-native version of Azul Zulu, and may have less version coverage than the images for other OSes.

### Azul Zulu for Azure ([`mcr.microsoft.com/java/jdk`](https://hub.docker.com/_/microsoft-java-jdk), [`mcr.microsoft.com/java/jre`](https://hub.docker.com/_/microsoft-java-jre), [`mcr.microsoft.com/java/jre-headless`](https://hub.docker.com/_/microsoft-java-jre-headless))
This is Microsoft's official image for Azul Zulu (now Azul Platform Core) for Azure.
- Java Versions: JDK, JRE, and Headless JRE for last LTS releases and last MTS releases (see [here](https://www.azul.com/products/azul-support-roadmap/))
- JVMs: HotSpot
- OSs: Alpine Linux, CentOS, Debian, Ubuntu, Windows Server Core, Windows Nano Server
- Architectures: `amd64`

**Important notice:**
> These Zulu OpenJDK for Azure Docker images and corresponding Dockerfiles **are to be used solely with Java applications** or Java application components that are **being developed for deployment on Microsoft Azure**, Azure Functions (anywhere), Azure Stack, or Microsoft SQL Server and are **not intended to be used for any other purpose**.
