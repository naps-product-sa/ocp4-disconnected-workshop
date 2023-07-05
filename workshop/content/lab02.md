Let's start with an overview of the disconnected installation process.

## Creating an Air Gap

## Preparing the Low Side
A disconnected installation begins with downloading content and tooling to a **prep server** that has access to the Internet. This server resides in an environment commonly referred to as the **Low Side** due to its low security profile. Compliance requirements usually prevent the low side from housing sensitive data or private information.

## Preparing the High Side
We then provision a **bastion server** which has no Internet access and resides in an environment commonly referred to as the **High Side** due to its high security profile. It is in the high side where sensitive data and production systems (like the cluster we're about to provision) live. During this phase, we'll need to transfer the content and tooling from the low side to the high side, a process which may entail use of a VPN or physical media like a DVD or USB.

## Preparing the Installation


## Running the Installation

## Accessing the Cluster