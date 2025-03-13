from _utils.utils import Utils
from _utils.database_schema import Base

def main():
    utils = Utils()
    utils.operation_start()

    Base.metadata.create_all(utils.database.engine)
    utils.log('info', 'Database schema created')

    utils.operation_end()

if __name__ == '__main__':
    main()
