/*
/// Module: bassinet_contracts
module bassinet_contracts::bassinet_contracts;
*/

// For Move coding conventions, see
// https://docs.sui.io/concepts/sui-move-concepts/conventions

module bassinet_contracts::bassinet_contracts;

use bassinet_contracts::digital_service::{Self, OpenFee};
use bassinet_contracts::launch_service::{Self, LaunchFee};

/// 获取开通收益
entry fun take_open_profits(admin_cap: &digital_service::AdminCap, self: &mut OpenFee, amount: Option<u64>, ctx: &mut TxContext){
    let profits = digital_service::take_profits(admin_cap, self, amount, ctx);
    if (profits.value() > 0) {
        transfer::public_transfer(profits, ctx.sender());
    }else {
        profits.destroy_zero();
    }
}

/// 获取发行收益
entry fun take_launch_profits(admin_cap: &launch_service::AdminCap, self: &mut LaunchFee, amount: Option<u64>, ctx: &mut TxContext){
    let profits = launch_service::take_profits(admin_cap, self, amount, ctx);
    if (profits.value() > 0) {
        transfer::public_transfer(profits, ctx.sender());
    }else {
        profits.destroy_zero();
    }
}