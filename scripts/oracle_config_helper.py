#!/usr/bin/env python3
"""
Oracle Cloud Configuration Helper
Guida passo-passo per configurare OCI CLI
"""

import os
import subprocess

def main():
    print("🔧 Oracle Cloud Configuration Helper")
    print("=" * 40)
    print()
    
    print("📋 Step 1: Get your OCIDs from Oracle Cloud Console")
    print("   1. Go to: https://cloud.oracle.com/")
    print("   2. Login to your account")
    print("   3. Click on your profile (top right)")
    print("   4. Click 'User Settings'")
    print("   5. Copy the 'OCID' (starts with ocid1.user.oc1...)")
    print()
    
    user_ocid = input("Enter your User OCID: ").strip()
    
    print()
    print("📋 Step 2: Get your Tenancy OCID")
    print("   1. Go to 'Administration' → 'Tenancy Details'")
    print("   2. Copy the 'OCID' (starts with ocid1.tenancy.oc1...)")
    print()
    
    tenancy_ocid = input("Enter your Tenancy OCID: ").strip()
    
    print()
    print("📋 Step 3: Choose Region")
    print("   Available regions:")
    print("   1. eu-frankfurt-1 (Europe - Frankfurt)")
    print("   2. us-ashburn-1 (US East - Ashburn)")
    print("   3. us-phoenix-1 (US West - Phoenix)")
    print("   4. ap-sydney-1 (Asia Pacific - Sydney)")
    print()
    
    region_choice = input("Choose region (1-4): ").strip()
    
    regions = {
        "1": "eu-frankfurt-1",
        "2": "us-ashburn-1", 
        "3": "us-phoenix-1",
        "4": "ap-sydney-1"
    }
    
    region = regions.get(region_choice, "eu-frankfurt-1")
    
    print()
    print("🔧 Step 4: Configure OCI CLI")
    print("Run this command:")
    print()
    print("oci setup config")
    print()
    print("When prompted, enter:")
    print(f"   User OCID: {user_ocid}")
    print(f"   Tenancy OCID: {tenancy_ocid}")
    print(f"   Region: {region}")
    print("   Generate API key: Y")
    print("   Directory for keys: [press Enter for default]")
    print("   Passphrase: [press Enter for no passphrase]")
    print()
    
    # Test configuration
    print("🧪 Testing configuration...")
    try:
        result = subprocess.run(['oci', 'iam', 'user', 'get', '--user-id', user_ocid], 
                              capture_output=True, text=True, timeout=30)
        if result.returncode == 0:
            print("✅ Configuration test successful!")
        else:
            print("❌ Configuration test failed. Please check your OCIDs and try again.")
    except Exception as e:
        print(f"❌ Error testing configuration: {e}")
    
    print()
    print("📝 Next steps:")
    print("   1. Run: oci setup config")
    print("   2. Test: oci iam user list --limit 1")
    print("   3. Deploy: ./deploy_oracle_50users.sh")

if __name__ == "__main__":
    main()
