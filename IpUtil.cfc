<cfscript>
/**
 * General purpose IP Address Utility functions.
 * Used in UpdateIPs.cfm on www2 to update the IP addresses for all the branch subnets.
 *
 * This function can be can instantiate an object with an IP address and subnet mask that sets
 * all the properties automatically, or it can be used as a library of static methods, which is
 * primarily how it is used in UpdateIPs.cfm.
 */
 component {
  property name="address" hint="Human-readable IPv4 address" type="string";
  property name="addressInt" hint="Integer IPv4 address" type="numeric";
  property name="subnetMask" hint="Human-readable subnet mask" type="string";
  property name="subnetMaskInt" hint="Integer subnet mask e.g., 24, 26, etc." type="numeric";
  property name="broadcastAddress" hint="Human-readable broadcast address" type="string";
  property name="broadcastAddressInt" hint="Integer broadcast address" type="numeric";
  property name="lastAddress" hint="Human-readable last address in a range" type="string";
  property name="lastAddressInt" hint="Integer last address in a range" type="numeric";

  function init(any ipAddress, any mask, lastAddress) {
    // Allow this to be instantiated with no arguments just to use the functions
    if (!arguments.keyExists('ipAddress')) return this

    // Convert and assign IP address to address and addressInt
    structAppend(this, convertFormats(ipAddress), true)

    // set lastAddress and lastAddressInt if provided
    if (len(arguments?.lastAddress)) structAppend(this, convertFormats(lastAddress, 'lastAddress'), true)

    // Handle setting subnet mask
    if (isNumeric(arguments?.mask)) {
      if (mask < 0 || mask > 32) throw('Invalid mask: Must be between 0 and 32.')
      this['subnetMaskInt'] = mask
    } else if (len(arguments?.mask) && this.validateSubnetMask(mask)) this.subnetMaskInt = this.subnetMaskToCIDR(mask)
    else if (len(arguments?.lastAddress)) this['subnetMaskInt'] = this.guessCIDRForRange(this.address, this.lastAddress)
    else this['subnetMaskInt'] = 24

    this['subnetMask'] = this.CIDRToSubnetMask(this.subnetMaskInt)

    // Calculate broadcast address
    this['broadcastAddress'] = this.broadcastAddress(this.address, this.subnetMask)
    this['broadcastAddressInt'] = this.ipToInt(this.broadcastAddress)

    // If no last address is provided, use the broadcast address
    if (!arguments.keyExists('lastAddress')) {
      this['lastAddress'] = this.broadcastAddress
      this['lastAddressInt'] = this.broadcastAddressInt
    }

    return this
  } // end init()

  // Accepts an ip address in any format and returns a struct with the address and addressInt
  private struct function convertFormats(any ip, type = 'address') {
    if (isNumeric(ip)) return { '#type#Int': ip, '#type#': intToIp(ip) }
    else if (validateIPv4Address(ip)) return { '#type#Int': ipToInt(ip), '#type#': ip }
    else throw('Invalid IP address.')
  }

  // Converts an IP address from human readable format to a 32-bit integer
  static numeric function ipToInt(string ipAddress) {
    var octets = listToArray(ipAddress, '.')
    return (octets[1] * (2^24)) + (octets[2] * (2^16)) + (octets[3] * (2^8)) + octets[4]
  }

  // Accepts integer IP address and returns human readable IP address using Java classes to handle large numbers
  static string function intToIp(numeric decimalIp) {
    var bigIntIp = createObject('java', 'java.math.BigInteger').init(decimalIp.toString())
    var big255 = createObject('java', 'java.math.BigInteger').init('255')
    var octets = []

    for (var i = 0; i <= 3; i++) octets.prepend(bigIntIp.shiftRight(i * 8).and(big255).intValue())

    return octets.toList('.')
  }

  // Validates an IP address and returns true if valid, otherwise throws an exception
  static boolean function validateIPv4Address(string ipv4Address) {
    var octets = ipv4Address.listToArray('.')

    if (octets.len() != 4) throw('Invalid IPv4 address: Must have 4 octets.')

    for (var octet in octets) {
      if (!isNumeric(octet) || val(octet) < 0 || val(octet) > 255) {
        throw('Invalid IPv4 address: Octets must be between 0 and 255.')
      }
    }

    return true
  }

  // Validates a subnet mask and returns true if valid, otherwise throws an exception
  static boolean function validateSubnetMask(string mask) {
    // Validate the IP address
    IpUtil::validateIPv4Address(mask)

    var binaryStr = ''
    // Convert each octet to binary and pad to 8 bits
    for (var octet in mask.listToArray('.')) binaryStr &= right('00000000' & formatBaseN(octet, 2), 8)

    // Ensure that the binary string contains only leading 1's followed by 0's
    if (binaryStr.reFind('^[1]+[0]*$') == 0) {
      throw('Invalid subnet mask: Must consist of leading 1s followed by 0s in binary.')
    }

    return true
  }

  // Converts a subnet mask from human readable format to an integer number of bits
  // If validate is true, it will validate the subnet mask and throw an exception if invalid
  static numeric function subnetMaskToCIDR(string mask, boolean validate = false) {
    if (validate) IpUtil::validateSubnetMask(mask)
    return mask.listToArray('.').map((octet) => Util::bitCount(octet)).sum()
  }

  // Note: This cannot be static because it uses the server.javaInt object
  // Converts a subnet mask from an integer number of bits to human readable format
  static string function CIDRToSubnetMask(numeric bits) {
    if (bits < 0 || bits > 32) throw('Invalid number of bits: Must be between 0 and 32.');

    var octets = []
    // Loop for each octet and append decimal representation for the current octet
    for (var i = 1; i <= 4 && bits > 0; i++) {
      octets.append(256 - 2^(8 - min(bits, 8)))
      bits -= 8
    }

    while (octets.len() < 4) octets.append(0)

    return octets.toList('.')
  }

  // Accepts any IP address (the first address in the range) and a subnet mask or mask length
  // and returns the broadcast address (the last address in the range)
  static string function broadcastAddress(string subnetAddress, required any maskLength) {
    if (!isNumeric(maskLength) && IpUtil::validateSubnetMask(maskLength)) maskLength = IpUtil::subnetMaskToCIDR(maskLength)
    if (maskLength < 0 || maskLength > 32) throw('Invalid maskLength: Must be between 0 and 32.')

    // Convert subnetAddress to BigInteger
    var subnetBigInt = createObject('java', 'java.math.BigInteger').init(IpUtil::ipToInt(subnetAddress))

    // Calculate inverted subnet mask
    var invertedMask = createObject('java', 'java.math.BigInteger').init(2^(32 - maskLength) - 1)

    // Calculate broadcast address by bitwise OR-ing
    var broadcastBigInt = subnetBigInt.or(invertedMask)

    // Convert back to IP string
    return IpUtil::intToIp(broadcastBigInt)
  }

  // Returns the smallest plausible CIDR subnet mask for a given IP address range
  static numeric function guessCIDRForRange(string firstAddress, string lastAddress) {
    // Validate addresses
    if (!isNumeric(firstAddress) && !validateIPv4Address(firstAddress)) throw('Invalid firstAddress: Must be a valid IPv4 address.')
    if (!isNumeric(lastAddress) && !validateIPv4Address(lastAddress)) throw('Invalid lastAddress: Must be a valid IPv4 address.')

    // Convert IP addresses to integers, if necessary
    var firstInt = !isNumeric(firstAddress) ? ipToInt(firstAddress) : firstAddress
    var lastInt = !isNumeric(lastAddress) ? ipToInt(lastAddress) : lastAddress

    // Calculate the number of addresses in the range and find the next power of 2
    var numberOfAddresses = lastInt - firstInt + 1
    var nextPowerOf2 = ceiling(log(numberOfAddresses) / log(2))

    // Calculate the prefix size (32 minus the log base 2 of the number of addresses)
    return 32 - nextPowerOf2
  }
}
</cfscript>