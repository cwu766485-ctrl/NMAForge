"""Contract tests, including counterexamples; Python standard library only."""
import unittest
from model import Entry


def entry():
    e = Entry()
    assert e.begin(256,32,7,10,1)
    for index in range(0,32,4):
        e.capture(256+4*index, list(range(index,index+4)))
    e.complete(True)
    e.retire(10,7,True)
    return e


def bind(e):
    return e.bind(256,32,7,10,1,{0:(7,10)})


class Contract(unittest.TestCase):
    def test_commit_mask_and_failed_write(self):
        for key in ('allowed','committed'):
            e=Entry();e.begin(256,32,7,10,1)
            e.capture(256,list(range(32)),**{key:False});e.complete(True)
            self.assertFalse(e.valid)
        e=Entry();e.begin(256,32,7,10,1)
        e.capture(256,list(range(32)),accepted=False);e.complete(True)
        self.assertFalse(e.valid)
        e=Entry();e.begin(256,32,7,10,1)
        e.capture(256,list(range(31)));e.complete(True)
        self.assertFalse(e.valid)

    def test_duplicate_and_failed_producer(self):
        e=Entry();e.begin(256,32,7,10,1)
        e.capture(256,[1]);e.capture(256,[1]);e.complete(True)
        self.assertFalse(e.valid)
        e=entry();e.retire(10,7,False);self.assertFalse(bind(e))
        e=Entry();e.begin(256,32,7,10,1)
        e.capture(256,list(range(32)));e.complete(False)
        self.assertFalse(e.valid)

    def test_epoch_dependency_format_and_length(self):
        for changes in [dict(epoch=8),dict(producer=11),dict(wait_mask=0),
                        dict(last_event_writer={0:(7,9)}),dict(fmt='packed_i8'),
                        dict(length=31),dict(base=260)]:
            kw=dict(base=256,length=32,epoch=7,producer=10,wait_mask=1,
                    last_event_writer={0:(7,10)})
            kw.update(changes)
            self.assertFalse(entry().bind(**kw))
        e=entry();e.retired=False;self.assertFalse(bind(e))
        self.assertTrue(bind(entry()))
        for base,length in [(257,32),(256,33),(131072,1)]:
            self.assertFalse(Entry().begin(base,length,0,0,1))

    def test_all_writers_and_byte_strobes(self):
        for writer in ('DMA','HOST','DEBUG','SFU','MATRIX_OTHER','KV','CPL'):
            e=entry();self.assertTrue(bind(e));e.request(0,'IDEAL_BYPASS')
            e.write(255,4,0b0010)
            self.assertFalse(e.valid,writer)
            self.assertIsNone(e.response(7,True),writer)
        e=entry();e.write(252,4);self.assertTrue(e.valid)
        e.write(256,4,0);self.assertTrue(e.valid)
        e.write(383,4,1);self.assertFalse(e.valid)

    def test_registered_exactly_once_backpressure_and_epoch(self):
        e=entry();bind(e)
        self.assertFalse(bind(e))
        self.assertTrue(e.lease)
        self.assertEqual(e.request(2,'IDEAL_BYPASS'),'REGISTERED_CACHE')
        self.assertIsNone(e.response(7,False))
        with self.assertRaises(RuntimeError):e.request(2,'IDEAL_BYPASS')
        self.assertFalse(e.begin(512,32,8,11,1))
        self.assertEqual(e.response(7,True),2)
        self.assertIsNone(e.response(7,True))
        e.request(3,'IDEAL_BYPASS');self.assertIsNone(e.response(8,True))
        self.assertFalse(e.valid)

    def test_reset_abort_fault_watchdog_wrap(self):
        for reason in ('RESET','ABORT','PARITY','PROTECTION','WATCHDOG','EPOCH_WRAP'):
            e=entry();bind(e);e.request(0,'IDEAL_BYPASS');e.invalidate()
            self.assertIsNone(e.response(7,True),reason)
            self.assertEqual(e.request(0,'IDEAL_BYPASS'),'SPAD_FALLBACK')

    def test_strict_permission_and_unobservable_sram_parity(self):
        e=entry();bind(e)
        self.assertEqual(e.request(0,'STRICT'),'SPAD_FALLBACK')
        self.assertEqual(e.request(0,'IDEAL_BYPASS',allowed=False),'PROTECTION_ERROR')
        e=entry();bind(e)
        self.assertEqual(e.request(0,'IDEAL_BYPASS',protection_epoch_stable=False),'SPAD_FALLBACK')
        # Two worlds: identical cache/snoop history, different silent SRAM upset.
        # Baseline reads distinguish them; cache state and cached parity cannot.
        a,b=entry(),entry();bind(a);bind(b)
        self.assertEqual(a,b)
        clean_sram,corrupt_sram=0,1
        self.assertNotEqual(clean_sram,corrupt_sram)
        self.assertEqual(a.request(0,'IDEAL_BYPASS'),b.request(0,'IDEAL_BYPASS'))
        self.assertEqual(a.response(7,True),b.response(7,True))
        self.assertEqual(a.data[0],0)


if __name__ == '__main__':
    unittest.main(verbosity=2)
