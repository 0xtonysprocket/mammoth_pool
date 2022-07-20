%lang starknet

from starkware.cairo.common.cairo_builtins import HashBuiltin
from starkware.starknet.common.syscalls import library_call, library_call_l1_handler

# openzeppelin
from openzeppelin.upgrades.library import Proxy

#
# Constructor
#

@constructor
func constructor{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        implementation_hash : felt, admin : felt):
    Proxy._set_implementation_hash(implementation_hash)
    Proxy.initializer(admin)
    return ()
end

#
# Fallback functions
#

@external
@raw_input
@raw_output
func __default__{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        selector : felt, calldata_size : felt, calldata : felt*) -> (
        retdata_size : felt, retdata : felt*):
    let (class_hash) = Proxy.get_implementation_hash()

    let (retdata_size : felt, retdata : felt*) = library_call(
        class_hash=class_hash,
        function_selector=selector,
        calldata_size=calldata_size,
        calldata=calldata)
    return (retdata_size=retdata_size, retdata=retdata)
end

###############
# SETTERS
###############

@external
func upgrade_implementation{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        implementation_hash : felt) -> ():
    alloc_locals
    Proxy.assert_only_admin()
    Proxy._set_implementation_hash(implementation_hash)
    return ()
end

@external
func transfer_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        new_admin : felt) -> ():
    alloc_locals
    Proxy.assert_only_admin()
    Proxy._set_admin(new_admin)
    return ()
end

###############
# VIEW
###############

@view
func get_implementation_hash{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}(
        ) -> (implementation_hash : felt):
    alloc_locals
    let (local hash : felt) = Proxy.get_implementation_hash()
    return (hash)
end

@view
func get_admin{syscall_ptr : felt*, pedersen_ptr : HashBuiltin*, range_check_ptr}() -> (
        admin : felt):
    alloc_locals
    let (local admin : felt) = Proxy.get_admin()
    return (admin)
end
