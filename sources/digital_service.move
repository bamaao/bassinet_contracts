// 开通数字服务
module bassinet_contracts::digital_service;

use sui::balance::{Self, Balance};
use sui::coin::{Self, Coin};
use sui::event;
use sui::sui::SUI;
use sui::ed25519::{Self};
use sui::package;
use std::string::{String};
use sui::table::{Self, Table};
use sui::url::{Self, Url};

/// Trying to take profits higher amount than stored.
const ENotEnough: u64 = 0;
/// The `Coin` used for payment is not enough to cover the fee.
const EInsufficientAmount: u64 = 1;
/// Account not exist
const EAccountNotExist: u64 = 2;
/// 重复绑定
const EBindAgain: u64 = 3;
/// 重复开通
const EOpenAgain: u64 = 4;

/// Admin
public struct AdminCap has key, store {
    id: UID
}

/// 开通服务收费
public struct OpenFee has key, store { 
    id: UID,
    balance: Balance<SUI>,
    // 计数
    count: u64,
    fee: u64,
    record: Table<address, String>,
    open_record: Table<address, bool>
}

public struct DIGITAL_SERVICE has drop {}

// ====== Events =========
public struct AccountBound has copy, drop {
    public_key: std::string::String,
    address: address,
    success: bool
}

public struct FeeInfo has copy, drop { 
    payment: u64,
    // 发行服务费
    fee: u64,
}

/// 开通服务事件
public struct DigitalServiceOpened has copy, drop {
    public_key: std::string::String,
    address: address,
    symbol: std::string::String,
    name: std::string::String,
    description: std::string::String,
    icon_url: Url
}

/// 服务费修改事件
public struct FeeChanged has copy, drop {
    before: u64,
    after: u64,
    changer: address
}

/// init
fun init(otw: DIGITAL_SERVICE, ctx: &mut TxContext) {
    let publisher = package::claim(otw, ctx);
    let sender = ctx.sender();

    let admin_cap = AdminCap {
        id: object::new(ctx)
    };

    let open_fee = OpenFee {
        id: object::new(ctx),
        balance: balance::zero(),
        count: 0,
        // SUI
        fee: 1_000,
        record: table::new<address, String>(ctx),
        open_record: table::new<address, bool>(ctx)
    };

    transfer::public_transfer(publisher, sender);
    transfer::public_transfer(admin_cap, sender);
    transfer::public_share_object(open_fee)
}

/// 绑定账户
public entry fun bind_account(fee: &mut OpenFee, signature: vector<u8>, public_key: vector<u8>, msg: vector<u8>, ctx: &mut TxContext) {
    let sender = ctx.sender();
    // hex 2 byte
    let sign = sui::hex::decode(signature);
    let pubkey= sui::hex::decode(public_key);
    let message = sui::hex::decode(msg);
    // 重复绑定
    assert!(!table::contains(&fee.record, sender), EBindAgain);

    let verify_result = ed25519::ed25519_verify(&sign, &pubkey, &message);
    let pub_key = std::string::utf8(public_key);
    if (verify_result) {
        event::emit(AccountBound{
            public_key: pub_key,
            address: sender,
            success: verify_result
        });
        table::add(&mut fee.record, sender, pub_key);
    }else {
        event::emit(AccountBound{
            public_key: pub_key,
            address: sender,
            success: verify_result
        });
    }
}

/// 开通数字服务
public entry fun open_digital_service(self: &mut OpenFee, symbol: vector<u8>, name: vector<u8>, description: vector<u8>, icon_url: vector<u8>, payment: &mut Coin<SUI>, ctx: &mut TxContext) {
    let sender = ctx.sender();

    event::emit(FeeInfo{
        payment: payment.value(),
        fee: self.fee
    });
    // 账户不存在
    assert!(table::contains(&self.record, sender), EAccountNotExist);
    // 重复开通
    assert!(!table::contains(&self.open_record, sender), EOpenAgain);
    // 费用不足
    assert!(payment.value() >= self.fee, EInsufficientAmount);

    let fee = payment.split(self.fee, ctx);
    coin::put(&mut self.balance, fee);
    self.count = self.count + 1;
    table::add(&mut self.open_record, sender, true);
    let pub_key = *account(self, sender);
    event::emit(DigitalServiceOpened {
        public_key: pub_key,
        address: sender,
        symbol: std::string::utf8(symbol),
        name: std::string::utf8(name),
        description: std::string::utf8(description),
        icon_url: url::new_unsafe_from_bytes(icon_url)
    });
}

/// 修改费用
public entry fun change_fee(_: &AdminCap, self: &mut OpenFee, fee: u64, ctx: &mut TxContext) {
    let before = self.fee;
    self.fee = fee;
    let sender = ctx.sender();
    event::emit(
        FeeChanged {
            before: before,
            after: fee,
            changer: sender
        }
    );
}

/// 获取收益
public fun take_profits(_: &AdminCap, self: &mut OpenFee, amount: Option<u64>, ctx: &mut TxContext): Coin<SUI> {
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
public fun profits_amount(self: &OpenFee): u64 {
    self.balance.value()
}

/// 开通数量
public fun count(self: &OpenFee): u64 {
    self.count
}

/// 是否可以发行
public(package) fun can_launch(self: &OpenFee, sender: address): bool {
    table::contains(&self.open_record, sender)
}

/// 对应的public_key
public(package) fun account(self: &OpenFee, sender: address): &String {
    table::borrow(&self.record, sender)
}

// TODO 重新绑定