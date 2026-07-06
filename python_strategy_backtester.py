#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
بوت تداول فوركس - استراتيجية RSI + Moving Averages
MT5 EUR/USD Backtester
"""

import pandas as pd
import numpy as np
from datetime import datetime, timedelta
import json

class ForexTradingBot:
    """بوت تداول فوركس احترافي"""
    
    def __init__(self, initial_balance=10000, lot_size=0.1, stop_loss=100, take_profit=200):
        """
        تهيئة البوت
        
        Args:
            initial_balance (float): الرصيد الأولي
            lot_size (float): حجم العقد
            stop_loss (int): Stop Loss بالنقاط
            take_profit (int): Take Profit بالنقاط
        """
        self.initial_balance = initial_balance
        self.current_balance = initial_balance
        self.lot_size = lot_size
        self.stop_loss = stop_loss
        self.take_profit = take_profit
        
        self.trades = []
        self.open_positions = []
        self.daily_profits = {}
        
        print("🤖 تم تهيئة بوت التداول بنجاح!")
        print(f"💰 الرصيد الأولي: ${initial_balance}")
        print(f"📊 حجم العقد: {lot_size}")
        print(f"🛑 Stop Loss: {stop_loss} نقطة")
        print(f"✅ Take Profit: {take_profit} نقطة\n")
    
    def calculate_rsi(self, prices, period=14):
        """حساب مؤشر القوة النسبية (RSI)"""
        deltas = np.diff(prices)
        seed = deltas[:period+1]
        up = seed[seed >= 0].sum() / period
        down = -seed[seed < 0].sum() / period
        rs = up / down if down != 0 else 0
        rsi = np.zeros_like(prices)
        rsi[:period] = 100. - 100. / (1. + rs)
        
        for i in range(period, len(prices)):
            delta = deltas[i-1]
            if delta > 0:
                upval = delta
                downval = 0.
            else:
                upval = 0.
                downval = -delta
            
            up = (up * (period - 1) + upval) / period
            down = (down * (period - 1) + downval) / period
            
            rs = up / down if down != 0 else 0
            rsi[i] = 100. - 100. / (1. + rs)
        
        return rsi
    
    def calculate_ema(self, prices, period=20):
        """حساب المتوسط المتحرك الأسي (EMA)"""
        return pd.Series(prices).ewm(span=period, adjust=False).mean().values
    
    def generate_signals(self, data, rsi_period=14, ma_period=20):
        """
        توليد إشارات التداول
        
        Args:
            data (pd.DataFrame): بيانات الأسعار
            rsi_period (int): فترة RSI
            ma_period (int): فترة المتوسط المتحرك
        
        Returns:
            pd.DataFrame: البيانات مع الإشارات
        """
        data['RSI'] = self.calculate_rsi(data['Close'].values, rsi_period)
        data['EMA'] = self.calculate_ema(data['Close'].values, ma_period)
        
        # إشارات
        data['Signal'] = 0
        data.loc[(data['RSI'] < 30) & (data['Close'] > data['EMA']), 'Signal'] = 1  # BUY
        data.loc[(data['RSI'] > 70) & (data['Close'] < data['EMA']), 'Signal'] = -1  # SELL
        
        return data
    
    def backtest(self, data):
        """
        اختبار الاستراتيجية على البيانات التاريخية
        
        Args:
            data (pd.DataFrame): بيانات الأسعار
        
        Returns:
            dict: نتائج الاختبار
        """
        data = self.generate_signals(data)
        
        for idx in range(1, len(data)):
            row = data.iloc[idx]
            
            # فتح صفقات
            if row['Signal'] == 1:  # BUY
                self.open_positions.append({
                    'type': 'BUY',
                    'entry_price': row['Close'],
                    'entry_time': row['Date'],
                    'sl': row['Close'] - (self.stop_loss * 0.0001),
                    'tp': row['Close'] + (self.take_profit * 0.0001)
                })
            
            elif row['Signal'] == -1:  # SELL
                self.open_positions.append({
                    'type': 'SELL',
                    'entry_price': row['Close'],
                    'entry_time': row['Date'],
                    'sl': row['Close'] + (self.stop_loss * 0.0001),
                    'tp': row['Close'] - (self.take_profit * 0.0001)
                })
            
            # إدارة الصفقات المفتوحة
            for position in self.open_positions[:]:
                profit = 0
                closed = False
                
                if position['type'] == 'BUY':
                    if row['Close'] >= position['tp']:
                        profit = (position['tp'] - position['entry_price']) * 10000 * self.lot_size
                        closed = True
                    elif row['Close'] <= position['sl']:
                        profit = -(self.stop_loss * self.lot_size)
                        closed = True
                
                elif position['type'] == 'SELL':
                    if row['Close'] <= position['tp']:
                        profit = (position['entry_price'] - position['tp']) * 10000 * self.lot_size
                        closed = True
                    elif row['Close'] >= position['sl']:
                        profit = -(self.stop_loss * self.lot_size)
                        closed = True
                
                if closed:
                    self.current_balance += profit
                    self.trades.append({
                        'type': position['type'],
                        'entry': position['entry_price'],
                        'exit': row['Close'],
                        'profit': profit,
                        'date': row['Date']
                    })
                    self.open_positions.remove(position)
        
        return self.get_results()
    
    def get_results(self):
        """الحصول على نتائج الاختبار"""
        total_trades = len(self.trades)
        winning_trades = len([t for t in self.trades if t['profit'] > 0])
        losing_trades = total_trades - winning_trades
        
        total_profit = sum([t['profit'] for t in self.trades])
        win_rate = (winning_trades / total_trades * 100) if total_trades > 0 else 0
        
        avg_win = (sum([t['profit'] for t in self.trades if t['profit'] > 0]) / winning_trades) if winning_trades > 0 else 0
        avg_loss = (sum([t['profit'] for t in self.trades if t['profit'] < 0]) / losing_trades) if losing_trades > 0 else 0
        
        return {
            'initial_balance': self.initial_balance,
            'final_balance': self.current_balance,
            'total_profit': total_profit,
            'profit_percentage': (total_profit / self.initial_balance * 100),
            'total_trades': total_trades,
            'winning_trades': winning_trades,
            'losing_trades': losing_trades,
            'win_rate': win_rate,
            'avg_win': avg_win,
            'avg_loss': abs(avg_loss),
            'profit_factor': abs(avg_win / avg_loss) if avg_loss != 0 else 0
        }
    
    def print_results(self):
        """طباعة النتائج"""
        results = self.get_results()
        
        print("\n" + "="*50)
        print("📊 نتائج الاختبار - Backtest Results")
        print("="*50)
        print(f"💰 الرصيد الأولي: ${results['initial_balance']:.2f}")
        print(f"💵 الرصيد النهائي: ${results['final_balance']:.2f}")
        print(f"📈 الربح الكلي: ${results['total_profit']:.2f}")
        print(f"📊 نسبة الربح: {results['profit_percentage']:.2f}%")
        print()
        print(f"🎯 إجمالي الصفقات: {results['total_trades']}")
        print(f"✅ صفقات رابحة: {results['winning_trades']}")
        print(f"❌ صفقات خاسرة: {results['losing_trades']}")
        print(f"📊 معدل النجاح: {results['win_rate']:.2f}%")
        print()
        print(f"💚 متوسط الربح: ${results['avg_win']:.2f}")
        print(f"💔 متوسط الخسارة: ${results['avg_loss']:.2f}")
        print(f"⚖️  نسبة الربح/الخسارة: {results['profit_factor']:.2f}")
        print("="*50)


if __name__ == "__main__":
    print("🤖 بوت تداول فوركس - Forex Trading Bot\n")
    
    # مثال: اختبار على بيانات عشوائية
    np.random.seed(42)
    dates = pd.date_range(start='2023-01-01', periods=252, freq='D')
    prices = 1.1 + np.cumsum(np.random.randn(252) * 0.002)
    
    data = pd.DataFrame({
        'Date': dates,
        'Close': prices
    })
    
    # تشغيل البوت
    bot = ForexTradingBot(initial_balance=10000, lot_size=0.1)
    bot.backtest(data)
    bot.print_results()
