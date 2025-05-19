// 发行NFT
module bassinet_contracts::launch_service;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;
use sui::package::{Self};
// use std::option::{Self, Option};
use std::string::{String};
use sui::table::{Self, Table};
// use sui::transfer;
use bassinet_contracts::digital_service::{Self, OpenFee};

// 默认最大发行限制一万
const DEFAULT_MAX_LIMIT: u64 = 10000;
// 最大发行限制百万
const MAX_LIMIT: u64 = 1000000;

/// Trying to take profits higher amount than stored.
const ENotEnough: u64 = 0;

/// The `Coin` used for payment is not enough to cover the fee.
const EInsufficientAmount: u64 = 1;

/// 没有开通
const ENotOpen: u64 = 2;

/// 重复发行
const ELaunchCollectionAgain: u64 = 3;

/// Admin
public struct AdminCap has key, store {
    id: UID
}

/// 发行服务收费
public struct LaunchFee has key, store { 
    id: UID,
    balance: Balance<SUI>,
    // 计数
    count: u64,
    // 发行服务费
    fee: u64,
    record: Table<String, bool>
}

/// NFT发行事件
public struct NftLaunched has copy, drop {
    public_key: String,
    address: address,
    collection_id: String,
    limit: u64,
    rewards_quantity: u64,
    minting_price: u64
}

/// 服务费修改事件
public struct FeeChanged has copy, drop {
    before: u64,
    after: u64,
    changer: address
}

public struct LAUNCH_SERVICE has drop {}

/// init
fun init(otw: LAUNCH_SERVICE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    let sender = ctx.sender();

    let admin_cap = AdminCap {
        id: object::new(ctx)
    };

    let launch_fee = LaunchFee {
        id: object::new(ctx),
        balance: balance::zero(),
        count: 0,
        // 1 SUI
        fee: 1_000_000_000,
        record: table::new<String, bool>(ctx)
    };

    transfer::public_transfer(publisher, sender);
    transfer::public_transfer(admin_cap, sender);
    transfer::public_share_object(launch_fee)
}

/// NFT发行
/// 对应的专辑ID，最大发行数量
public entry fun launch(self: &mut LaunchFee, open_fee: &OpenFee, collection_id: vector<u8>, limit: Option<u64>, rewards_quantity: u64, minting_price: u64,  payment: &mut Coin<SUI>, ctx: &mut TxContext) {
     let sender = ctx.sender();
     assert!(digital_service::can_launch(open_fee, sender), ENotOpen);

     let collection = std::string::utf8(collection_id);

    assert!(!table::contains(&self.record, collection), ELaunchCollectionAgain);
    assert!(payment.value() >= self.fee, EInsufficientAmount);

    let mut max = if (limit.is_some()) {
        limit.destroy_some()
    } else {
        DEFAULT_MAX_LIMIT
    };

    if (max > MAX_LIMIT) {
        max = MAX_LIMIT;
    };

    let fee = payment.split(self.fee, ctx);
    coin::put(&mut self.balance, fee);
    self.count = self.count + 1;
    
    let pub_key = *digital_service::account(open_fee, sender);
    event::emit(NftLaunched {
        public_key: pub_key,
        address: sender,
        collection_id: collection,
        limit: max,
        rewards_quantity: rewards_quantity,
        minting_price: minting_price
    });

    table::add(&mut self.record, collection, true)
}

/// 修改费用
public entry fun change_fee(self: &mut LaunchFee, _: &AdminCap, fee: u64, ctx: &mut TxContext) {
    let before = self.fee;
    self.fee = fee;
    let sender = ctx.sender();
    event::emit(
        FeeChanged {
            before: before,
            after: fee,
            changer: sender
        }
    )
}

/// 获取收益
public fun take_profits(_: &AdminCap, self: &mut LaunchFee, amount: Option<u64>, ctx: &mut TxContext): Coin<SUI> {
    let amount = if (amount.is_some()) {
        let amt = amount.destroy_some();
        assert!(amt <= self.balance.value(), ENotEnough);
        amt
    } else {
        self.balance.value()
    };
    coin::take(&mut self.balance, amount, ctx)
}

/// 查看收益
public fun profits_amount(self: &LaunchFee): u64 {
    self.balance.value()
}

/// 发行数量
public fun count(self: &LaunchFee): u64 {
    self.count
}