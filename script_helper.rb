################################################################################
# BMC Software, Inc.
# Confidential and Proprietary
# Copyright (c) BMC Software, Inc. 2001-2012
# All Rights Reserved.
################################################################################

# Private Routines to Support scriping #
# BJB 9/8/10
require 'base64'
require 'nori'
PRIVATE_PREFIX = "__SS__"  # Must also change in config/environment.rb and streamstep.py

def strip_private_flag(params)
  params.each do |item, val|
    if val.class == String
      params[item] = decrypt(val.gsub(PRIVATE_PREFIX, "")) if val.include?(PRIVATE_PREFIX)
    end
  end
end

def decrypt_string_with_prefix(val)
  unless val.blank?
    decrypt(val.gsub(PRIVATE_PREFIX, ""))
  else
    val
  end
end

def decrypt(val)
  enc = Base64::decode64(val).reverse
  enc = Base64::decode64(enc).gsub(PRIVATE_PREFIX,"")
end

def encrypt(val)
  enc = Base64::encode64(val).reverse
  enc = PRIVATE_PREFIX + Base64::encode64(enc).gsub("\n","")
end  

def sub_tokens(script_params,var_string)
  prop_val = var_string.match('rpm{[^{}]*}')
  while ! prop_val.nil? do
    var_string = var_string.sub(prop_val[0],script_params[prop_val[0][4..-2]])
    prop_val = var_string.match('rpm{[^{}]*}')
  end
  return var_string
end

